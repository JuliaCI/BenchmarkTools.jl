# Reproducible benchmarking in Linux-based environments

- [Introduction](#introduction)
- [Processor shielding and process affinity](#processor-shielding-and-process-affinity)
- [Interrupt requests and SMP affinity](#interrupt-requests-and-smp-affinity)
- [Hyperthreading](#hyperthreading)
- [Swappiness and other virtual memory settings](#swappiness-and-other-virtual-memory-settings)
- [CPU frequency scaling and boosting](#cpu-frequency-scaling-and-boosting)
- [Additional resources](#additional-resources)

### Introduction

To the uninitiated, tracking down and eliminating "OS jitter" can sometimes feel more like an art than a science. You'll quickly find that setting up a proper environment for rigorous performance testing requires scouring the internet and academic literature for esoteric references to scheduler quirks and kernel flags. Some of these parameters might drastically affect the outcome of your particular benchmark suite, while others may demand inordinate amounts of experimentation just to prove that they don't affect your benchmarks at all.

When I started working on performance regression testing for the Julia language, I was surprised that I couldn't find an up-to-date and noob-friendly checklist that succinctly consolidated the performance wisdom scattered across various forums and papers. My hope is that this document provides a starting point for researchers who are new to performance testing on Linux, and who might be trying to figure out why theoretically identical benchmark trials generate significantly different results. In other words, *this document is all about identifying and avoiding potential reproducibility pitfalls in a Linux-based benchmarking environment*.

This document's goal is *not* to improve the performance of your application, help you simulate a realistic production environment, or provide in-depth explanations for various kernel mechanisms. It is currently a bit light on NUMA-specific details, but alas, I don't have access to a NUMA-enabled machine to play with. I'm sure that knowledgable readers this will find opportunities for corrections and additions, in which case I'd be grateful if you filed an issue or opened a pull request in this repository.

### Processor shielding and process affinity

Processor shielding is a technique that invokes Linux's [`cpuset`](http://man7.org/linux/man-pages/man7/cpuset.7.html) interface to set up exclusive processors and memory nodes (if on a NUMA-enabled machine) that are protected from Linux's scheduler. The easiest way to create and utilize a processor shield is with the [`cset`](http://manpages.ubuntu.com/manpages/precise/man1/cset.1.html) utility, which is a convenient Python wrapper over `cpuset`. Install it by running the following:

```
➜ sudo apt-get install cpuset
```

It's worth reading the [extensive `cset` tutorial](https://rt.wiki.kernel.org/index.php/Cpuset_Management_Utility/tutorial) available on RTwiki, but as a short example, here's how you would shield processors 1 and 3 from current and new processes (including most kernel threads, specified by `-k on`):

```
➜ sudo cset shield -c 1,3 -k on
cset: --> activating shielding:
cset: moving 67 tasks from root into system cpuset...
[==================================================]%
cset: kthread shield activated, moving 91 tasks into system cpuset...
[==================================================]%
cset: **> 34 tasks are not movable, impossible to move
cset: "system" cpuset of CPUSPEC(0,2) with 124 tasks running
cset: "user" cpuset of CPUSPEC(1,3) with 0 tasks running
```

Administrators of NUMA-enabled machines should also be aware of the `-m` flag, which tells `cset` to shield memory nodes.

After setting up a shield, you can execute processes within it via the `-e` flag (note that arguments to the process must be provided after the `--` separator):

```
➜ sudo cset shield -e echo -- "hello from within the shield"
cset: --> last message, executed args into cpuset "/user", new pid is: 27782
hello from within the shield
➜ sudo cset shield -e julia -- benchmark.jl
cset: --> last message, executed args into cpuset "/user", new pid is: 27792
running benchmarks...
```

For slightly lower-level control, you can use `cset`'s other subcommands, [`proc`](https://rt.wiki.kernel.org/index.php/Cpuset_Management_Utility/tutorial#The_Proc_Subcommand) and [`set`](https://rt.wiki.kernel.org/index.php/Cpuset_Management_Utility/tutorial#The_Set_Subcommand). The actual `cpuset` kernel interface [offers even more options](http://man7.org/linux/man-pages/man7/cpuset.7.html#EXTENDED_CAPABILITIES), notably memory hardwalling and scheduling settings.

To maximize reproducibility, I recommend creating [hierarchal cpusets](https://rt.wiki.kernel.org/index.php/Cpuset_Management_Utility/tutorial#Implementing_Hierarchy_with_Set_and_Proc) within the shield to ensure that repeated experiments use the exact same processor/memory configuration. By setting up child cpusets of the shield cpuset, you can essentially pin processes to individual processors and memory nodes, obviating the need for other commands like `taskset`, `numactl`, or `tuna`. These other tools, while great in their own right, aren't as useful in this case because they don't protect your processes from the scheduler like `cset` does.

### Interrupt requests and SMP affinity

The kernel will periodically send [interrupt requests (IRQs)](https://en.wikipedia.org/wiki/Interrupt_request_(PC_architecture)) to your processors. As the name implies, IRQs essentially ask a processor to pause the currently running task in order to perform the requested task. There are many different kinds of IRQs, and the degree to which a specific kind of IRQ interferes with a given benchmark depends on the frequency and duration of the IRQ compared to the benchmark's workload.

The good news is that most kinds of IRQs allow you to set an [SMP affinity](https://cs.uwaterloo.ca/~brecht/servers/apic/SMP-affinity.txt), which tells the kernel which processor an IRQ should be sent to. By properly configuring SMP affinities, we can send IRQs to the unshielded processors in our benchmarking environment, thus protecting the shielded processors from undesirable interruptions.

To get a list of interrupts that have occurred on your system since your last reboot, run the following (the output is shortened for readability):

```
➜  ~ cat /proc/interrupts
           CPU0       CPU1
  0:         19          0  IR-IO-APIC-edge      timer
  8:          1          0  IR-IO-APIC-edge      rtc0
  9:          0          0  IR-IO-APIC-fasteoi   acpi
 16:         27          0  IR-IO-APIC-fasteoi   ehci_hcd:usb1
 22:         12          0  IR-IO-APIC-fasteoi   ehci_hcd:usb2
 ⋮
 53:   18021763     122330  IR-PCI-MSI-edge      eth0-TxRx-7
NMI:      15661      13628  Non-maskable interrupts
LOC:  140221744   85225898  Local timer interrupts
SPU:          0          0  Spurious interrupts
PMI:      15661      13628  Performance monitoring interrupts
IWI:   23570041    3729274  IRQ work interrupts
RTR:          7          0  APIC ICR read retries
RES:    3153272    4187108  Rescheduling interrupts
CAL:       3401      10460  Function call interrupts
TLB:    4434976    3071723  TLB shootdowns
TRM:          0          0  Thermal event interrupts
THR:          0          0  Threshold APIC interrupts
MCE:          0          0  Machine check exceptions
MCP:      61112      61112  Machine check polls
ERR:          0
MIS:          0
```

You can easily set the SMP affinity of an IRQ by writing processor indices to `/proc/irq/n/smp_affinity_list`, where `n` is the IRQ number. Here's an example of telling the kernel to send IRQ `22` to processors `0`, `1`, and `2`:

```
➜ echo 0-2 | sudo tee /proc/irq/22/smp_affinity_list
```

The optimal way to configure SMP affinities depends a lot on your benchmarks and your benchmarking process itself. For example, if you're running a lot of network-bound benchmarks, it can sometimes be more beneficial to evenly balance ethernet driver interrupts (usually named something like `eth0-*`) than to restrict them to specific processors. Note that some IRQs (notably [non-maskable interrupts (`NMI`)](https://en.wikipedia.org/wiki/Non-maskable_interrupt)) can't be redirected to other processors.

A useful - but not at all foolproof - smoke test for determining how much effort you should invest into experimenting with SMP affinities is to check whether benchmark results drastically change if you use a load balancer like [`irqbalance`](http://linux.die.net/man/1/irqbalance) (on some systems, the `irqbalance` daemon is enabled by default). If turning on/off the `irqbalance` daemon has a noticeable effect on your results, it's worth playing around with SMP affinities to figure out which IRQs should be directed away from your shielded processors.

The Linux kernel's [`perf`](https://perf.wiki.kernel.org/index.php/Main_Page) subsystem, which primarily sends performance monitoring interrupts (PMIs), is worth special attention. One of `perf`'s central features is its ability to set and manage [hardware performance counters](https://en.wikipedia.org/wiki/Hardware_performance_counter), which are regularly monitored by other parts of the kernel for various reasons. Obviously, the `perf` tool is extremely useful for gathering low-level performance information, and may very well be a dependency of your benchmarking process.

If it isn't used by your benchmarking process, however, than it may be useful to lower `perf`'s sample rate so that its interrupts don't overly affect your experiments. One way to do this is to set the [`kernel.perf_cpu_time_max_percent`](https://www.kernel.org/doc/Documentation/sysctl/kernel.txt) parameter to `1`:

```
➜ sudo sysctl kernel.perf_cpu_time_max_percent=1
```

This tells the kernel to inform `perf` that it should lower its sample rate such that sampling consumes less than 1% of CPU time. After changing this parameter, you may find messages in `dmesg` pop up that look similar to:

```
[ 3835.065463] perf samples too long (2502 > 2500), lowering kernel.perf_event_max_sample_rate
```

These messages are nothing to be concerned about - it's simply the kernel reporting that it's lowering `perf`'s max sample rate in order to respect the `perf_cpu_time_max_percent` property we just set.

### Hyperthreading

When hyperthreading interferes with a benchmark, the cause and nature of the interference can be difficult to track down. Unless you explicitly wish to measure your code's performance in a hyperthreaded environment, disabling hyperthreading can reduce noise and make other timing variations easier to reason about.

The first step to disable hyperthreading is to check whether it's enabled on your machine. To do so, you can use `lscpu`:

```
➜ lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                8        
On-line CPU(s) list:   0-7
Thread(s) per core:    2       
Core(s) per socket:    4       
Socket(s):             1
NUMA node(s):          1
Vendor ID:             GenuineIntel
CPU family:            6
Model:                 60
Stepping:              3
CPU MHz:               3501.000
BogoMIPS:              6999.40
Virtualization:        VT-x
L1d cache:             32K
L1i cache:             32K
L2 cache:              256K
L3 cache:              8192K
NUMA node0 CPU(s):     0-7
```

In the above output, the `CPU(s)` field tells us there are `8` *logical cores*. The other
fields allow us to do a more granular breakdown: `1` socket times `4` cores per socket gives
us `4` physical cores, times `2` threads per core gives us `8` logical cores. Since there
are more logical cores than physical cores, we know hyperthreading is enabled.

We can disable the excess virtual cores by taking them offline:

```
➜ echo 0 | sudo tee /sys/devices/system/cpu/cpu4/online
0
➜ echo 0 | sudo tee /sys/devices/system/cpu/cpu5/online
0
➜ echo 0 | sudo tee /sys/devices/system/cpu/cpu6/online
0
➜ echo 0 | sudo tee /sys/devices/system/cpu/cpu7/online
0
```

You can check whether that worked by running `lscpu` again:

```
➜ lscpu | grep Thread
Thread(s) per core:    1
```

### Swappiness and other virtual memory settings

Many Linux distributions are configured to [swap](https://wiki.archlinux.org/index.php/swap) aggressively by default, which can heavily skew performance results by increasing the likelihood of swapping during benchmark execution. Luckily, it's easy to tame the kernel's propensity to swap by lowering the [swappiness](https://en.wikipedia.org/wiki/Swappiness) setting, controlled via the `vm.swappiness` parameter:

```
➜ sudo sysctl vm.swappiness=10
```

In my experience, lowering `vm.swappiness` to around `10` or so is sufficient to defeat noise on most memory-bound benchmarks, but there are a few other parameters for configuring Linux's paging/caching behavior that could affect benchmark reproducibility:

- `vm.nr_hugepages`
- `vm.vfs_cache_pressure`
- `vm.zone_reclaim_mode`
- `vm.min_free_kbytes`

Documentation for these parameters can be found [here](https://www.kernel.org/doc/Documentation/sysctl/vm.txt).

Another memory-related source of noise is [address space layout randomization (ASLR)](https://en.wikipedia.org/wiki/Address_space_layout_randomization), a security feature that makes it harder for malicious programs to exploit buffer overflows. I haven't personally observed ASLR skewing benchmark results, but in theory ASLR could affect benchmarks that are highly susceptible to changes in memory layout. Obviously, disabling ASLR should be done at your own risk - it *is* a security feature, after all.

ASLR can be disabled globally by setting `randomize_va_space` to `0`:

```
➜ sudo sysctl kernel.randomize_va_space=0
```

If you don't wish to disable ASLR globally, you can simply start up an ASLR-disabled shell by running:

```
➜ setarch $(uname -m) -R /bin/bash
```

### CPU frequency scaling and boosting

In many Linux distributions, some form of CPU frequency scaling is enabled by default. Frequency scaling can save power and help with temperature control, but obviously has the potential to interfere with getting consistent benchmark results. To make sure that the CPU doesn't suddenly get faster in the middle of a performance test, set the frequency scaling governor to `performance` on all cores:

```
➜ echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

You can check that this worked by making sure that `cat /proc/cpuinfo | grep 'cpu MHz'` spits out the same values as `cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq`.

You should also disable [frequency boosting](https://www.kernel.org/doc/Documentation/cpu-freq/boost.txt) if your CPU supports it:

```
➜ echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost
```

### Additional resources

- While not highly navigable and a bit overwhelming for newcomers, the most detailed resource is the official Linux documentation  hosted at [the Linux Kernel Archives](https://www.kernel.org/doc/Documentation/).

- For a solid overview of the Linux performance testing ecosystem, check out [Brendan Gregg's talk on Linux performance tools](https://www.youtube.com/watch?v=FJW8nGV4jxY). Note that this talk is more focused on debugging system performance problems as they arise in a large distributed environment, rather than application benchmarking or experimental reproducibility.

- The [RHEL6 Performance Tuning Guide](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Performance_Tuning_Guide/) is useful for introducing yourself to various kernel constructs that can cause performance problems (and/or fix them). You can also check out the [RHEL7 version](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Performance_Tuning_Guide/) of the same guide if you want something more recent, but I find the RHEL6 version more readable.
