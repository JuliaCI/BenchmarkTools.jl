# Reproducible benchmarking in Linux-based environments

## Introduction

This document is all about identifying and avoiding potential reproducibility pitfalls when executing performance tests in a Linux-based environment.

When I started working on performance regression testing for the Julia language, I was surprised that I couldn't find an up-to-date and noob-friendly checklist that succinctly consolidated the performance wisdom scattered across various forums and papers. My hope is that this document provides a starting point for researchers who are new to performance testing on Linux, and who might be trying to figure out why theoretically identical benchmark trials generate significantly different results.

To the uninitiated, tracking down and eliminating "OS jitter" can sometimes feel more like an art than a science. You'll quickly find that setting up a proper environment for rigorous performance testing requires scouring the internet and academic literature for esoteric references to scheduler quirks and kernel flags. Some of these parameters might drastically affect the outcome of your particular benchmark suite, while others may demand inordinate amounts of experimentation just to prove that they don't affect your benchmarks at all.

This document's goal is *not* to improve the performance of your application, help you simulate a realistic production environment, or provide in-depth explanations for various kernel mechanisms. It is currently a bit light on NUMA-specific details, but alas, I don't have access to a NUMA-enabled machine to play with. I'm sure that knowledgable readers will find opportunities for corrections and additions, in which case I'd be grateful if you filed an issue or opened a pull request in this repository.

## Processor shielding and process affinity

Processor shielding is a technique that invokes Linux's [`cpuset`](http://man7.org/linux/man-pages/man7/cpuset.7.html) pseudo-filesystem to set up exclusive processors and memory nodes that are protected from Linux's scheduler. The easiest way to create and utilize a processor shield is with [`cset`](http://manpages.ubuntu.com/manpages/precise/man1/cset.1.html), a convenient Python wrapper over the `cpuset` interface. On Ubuntu, `cset` can be installed by running the following:

```
➜ sudo apt-get install cpuset
```

It's worth reading the [extensive `cset` tutorial](https://rt.wiki.kernel.org/index.php/Cpuset_Management_Utility/tutorial) available on RTwiki. As a short example, here's how one might shield processors 1 and 3 from uninvited threads (including most kernel threads, specified by `-k on`):

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

To maximize consistency between trials, you should make sure that individual threads executed within the shield always use the exact same processor/memory node configuration. This can be accomplished using [hierarchical cpusets](https://rt.wiki.kernel.org/index.php/Cpuset_Management_Utility/tutorial#Implementing_Hierarchy_with_Set_and_Proc) to pin processes to child cpusets created under the shielded cpuset. Other utilities for managing process affinity, like `taskset`, `numactl`, or `tuna`, aren't as useful as `cset` because they don't protect dedicated resources from the scheduler.

## Virtual memory settings

The official Linux documentation lists [a plethora of virtual memory settings](https://www.kernel.org/doc/Documentation/sysctl/vm.txt) for configuring Linux's swapping, paging, and caching behavior.
I encourage the reader to independently investigate the `vm.nr_hugepages`, `vm.vfs_cache_pressure`, `vm.zone_reclaim_mode`, and `vm.min_free_kbytes` properties, but won't discuss these in-depth because they are not likely to have a large impact in the majority of cases. Instead, I'll focus on two properties which are easier to experiment with and a bit less subtle in their effects: swappiness and address space layout randomization.

### Swappiness

Most Linux distributions are configured to [swap](https://wiki.archlinux.org/index.php/swap) aggressively by default, which can heavily skew performance results by increasing the likelihood of swapping during benchmark execution. Luckily, it's easy to tame the kernel's propensity to swap by lowering the [swappiness](https://en.wikipedia.org/wiki/Swappiness) setting, controlled via the `vm.swappiness` parameter:

```
➜ sudo sysctl vm.swappiness=10
```

In my experience, lowering `vm.swappiness` to around `10` or so is sufficient to overcome swap-related noise on most memory-bound benchmarks.

### Address space layout randomization (ASLR)

[Address space layout randomization (ASLR)](https://en.wikipedia.org/wiki/Address_space_layout_randomization) is a security feature that makes it harder for malicious programs to exploit buffer overflows. In theory, ASLR could significantly impact reproducibility for benchmarks that are highly susceptible to variations in memory layout. Disabling ASLR should be done at your own risk - it *is* a security feature, after all.

ASLR can be disabled globally by setting `randomize_va_space` to `0`:

```
➜ sudo sysctl kernel.randomize_va_space=0
```

If you don't wish to disable ASLR globally, you can simply start up an ASLR-disabled shell by running:

```
➜ setarch $(uname -m) -R /bin/sh
```

## CPU frequency scaling and boosting

Most modern CPUs support dynamic frequency scaling, which is the ability to adjust their clock rate in order to manage power usage and temperature. On Linux, frequency scaling behavior is determined by heuristics dubbed ["governors"](https://www.kernel.org/doc/Documentation/cpu-freq/governors.txt), each of which prioritizes different patterns of resource utilization. This feature can interfere with performance results if rescaling occurs during benchmarking or between trials, but luckily we can keep the effective clock rate static by enabling the `performance` governor on all processors:

```
➜ echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

You can check that this command worked by making sure that `cat /proc/cpuinfo | grep 'cpu MHz'` spits out the same values as `cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq`.

Many CPUs also support discretionary performance ["boosting"](https://www.kernel.org/doc/Documentation/cpu-freq/boost.txt), which is similar to dynamic frequency scaling and can have the same negative impacts on benchmark reproducibility. To disable CPU boosting, you can run the following:

```
➜ echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost
```

## Hyperthreading

Hyperthreading, more generally known as [simultaneous multithreading (SMT)](https://en.wikipedia.org/wiki/Simultaneous_multithreading), allows multiple software threads to "simultaneously" run on "independent" hardware threads on a single CPU core. The downside is that these threads can't always actually execute concurrently in practice, as they contend for shared CPU resources. Frustratingly, Linux exposes these threads to the operating system as extra logical processors, making techniques like shielding difficult to reason about - how do you know that your shielded "processor" isn't actually sharing a physical core with an unshielded "processor"? Unless your use case demands that you run tests in a hyperthreaded environment, you should consider disabling hyperthreading to make it easier to manage processor resources consistently.

The first step to disabling hyperthreading is to check whether it's actually enabled on your machine. To do so, you can use `lscpu`:

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

In the above output, the `CPU(s)` field tells us there are `8` *logical processors*. The other
fields allow us to do a more granular breakdown: `1` socket times `4` cores per socket gives
us `4` physical cores, times `2` threads per core gives us `8` logical processors. Since there
are more logical processors than physical cores, we know hyperthreading is enabled.

Before we start disabling processors, we need to know which ones share a physical core:

```
➜ cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list
0,4
1,5
2,6
3,7
0,4
1,5
2,6
3,7
```

Each row above is in the format `i,j`, and can be read `logical processor i shares a physical core with logical processor j`.
We can disable hyperthreading by taking excess sibling processors offline, leaving only one logical processor per physical core. In our example, we can accomplish this by disabling processors `4`, `5`, `6`, and `7`:

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

Now, we can verify that hyperthreading is disabled by checking each processor's `thread_siblings_list` again:

```
➜ cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list
0
1
2
3
```

## Interrupt requests and SMP affinity

The kernel will periodically send [interrupt requests (IRQs)](https://en.wikipedia.org/wiki/Interrupt_request_(PC_architecture)) to your processors. As the name implies, IRQs ask a processor to pause the currently running task in order to perform the requested task. There are many different kinds of IRQs, and the degree to which a specific kind of IRQ interferes with a given benchmark depends on the frequency and duration of the IRQ compared to the benchmark's workload.

The good news is that most kinds of IRQs allow you to set an [SMP affinity](https://cs.uwaterloo.ca/~brecht/servers/apic/SMP-affinity.txt), which tells the kernel which processor an IRQ should be sent to. By properly configuring SMP affinities, we can send IRQs to the unshielded processors in our benchmarking environment, thus protecting the shielded processors from undesirable interruptions.

You can use Linux's `proc` pseudo-filesystem to get a list of interrupts that have occurred on your system since your last reboot:

```
➜ cat /proc/interrupts
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

Some interrupts, like [non-maskable interrupts (`NMI`)](https://en.wikipedia.org/wiki/Non-maskable_interrupt), can't be redirected, but you can change the SMP affinities of the rest by writing processor indices to `/proc/irq/n/smp_affinity_list`, where `n` is the IRQ number. Here's an example that sets IRQ `22`'s SMP affinity to processors `0`, `1`, and `2`:

```
➜ echo 0-2 | sudo tee /proc/irq/22/smp_affinity_list
```

The optimal way to configure SMP affinities depends a lot on your benchmarks and benchmarking process. For example, if you're running a lot of network-bound benchmarks, it can sometimes be more beneficial to evenly balance ethernet driver interrupts (usually named something like `eth0-*`) than to restrict them to specific processors.

A smoke test for determining the impact of IRQs on benchmark results is to see what happens when you turn on/off an IRQ load balancer like [`irqbalance`](http://linux.die.net/man/1/irqbalance). If this has a noticeable effect on your results, it might be worth playing around with SMP affinities to figure out which IRQs should be directed away from your shielded processors.

#### Performance monitoring interrupts (PMIs) and `perf`

Performance monitoring interrupts (PMIs) are sent by the kernel's [`perf`](https://perf.wiki.kernel.org/index.php/Main_Page) subsystem, which is used to set and manage [hardware performance counters](https://en.wikipedia.org/wiki/Hardware_performance_counter) monitored by other parts of the kernel. Unless `perf` is a dependency of your benchmarking process, it may be useful to lower `perf`'s sample rate so that PMIs don't interfere with your experiments. One way to do this is to set the [`kernel.perf_cpu_time_max_percent`](https://www.kernel.org/doc/Documentation/sysctl/kernel.txt) parameter to `1`:

```
➜ sudo sysctl kernel.perf_cpu_time_max_percent=1
```

This tells the kernel to inform `perf` that it should lower its sample rate such that sampling consumes less than 1% of CPU time. After changing this parameter, you may see messages in the system log like:

```
[ 3835.065463] perf samples too long (2502 > 2500), lowering kernel.perf_event_max_sample_rate
```

These messages are nothing to be concerned about - it's simply the kernel reporting that it's lowering `perf`'s max sample rate in order to respect the `perf_cpu_time_max_percent` property we just set.

## Additional resources

- While not highly navigable and a bit overwhelming for newcomers, the most authoritative resource for kernel information is the official Linux documentation hosted at [the Linux Kernel Archives](https://www.kernel.org/doc/Documentation/).

- Akkan et al.'s [2012 paper on developing a noiseless Linux environment](http://dl.acm.org/citation.cfm?id=2318925) explores the optimal configurations for isolating resources from timer interrupts and the scheduler, as well as the benefits of tickless kernels. The paper makes use of Linux's [`cgroups`](https://wiki.archlinux.org/index.php/Cgroups), which are similar to the cpusets discussed in this document.

- De et al.'s [2009 paper on reducing OS jitter in multithreaded systems](http://ieeexplore.ieee.org/xpls/abs_all.jsp?arnumber=5161046&tag=1) is similar to Akkan et al.'s paper, but focuses on minimizing jitter for applications that make use of hyperthreading/SMT. Their experimental approach is different as well, relying heavily on analysis of simulated jitter "traces" attained by clever benchmarking.

- For a solid overview of the Linux performance testing ecosystem, check out [Brendan Gregg's talk on Linux performance tools](https://www.youtube.com/watch?v=FJW8nGV4jxY). Note that this talk is more focused on debugging system performance problems as they arise in a large distributed environment, rather than application benchmarking or experimental reproducibility.

- The [RHEL6 Performance Tuning Guide](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Performance_Tuning_Guide/) is useful for introducing yourself to various kernel constructs that can cause performance problems. You can also check out the [RHEL7 version](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Performance_Tuning_Guide/) of the same guide if you want something more recent, but I find the RHEL6 version more readable.
