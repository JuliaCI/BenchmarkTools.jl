using Pkg
Pkg.activate(; temp=true)
Pkg.add("Luxor")
using Luxor

JULIA_COLORS = [Luxor.julia_blue, Luxor.julia_green, Luxor.julia_red, Luxor.julia_purple]

function draw_logo(; path, dark=false)
    Drawing(500, 500, path)
    origin()
    squircle(O, 250, 250, :clip; rt=0.3)
    sethue(dark ? "black" : "white")
    paint()

    @layer begin
        translate(0, 200)
        rmin = 150
        rmax = 260
        band = 40

        for n in 1:4
            setblend(blend(O - (240, 0), O + (240, 0), "white", JULIA_COLORS[n]))
            sector(
                O,
                rescale(n, 1, 3, rmin, rmax),
                rescale(n, 1, 3, rmin, rmax) + band,
                3π / 2 - deg2rad(45),
                3π / 2 + deg2rad(45),
                :fill,
            )
        end

        sethue(dark ? "black" : "white")
        setline(25)
        line(O, polar(400, deg2rad(290)), :strokepreserve)
        setline(14)
        sethue(dark ? "white" : "black")
        strokepath()
        circle(O, 30, :fill)
    end

    finish()
    return preview()
end

draw_logo(; path=joinpath(@__DIR__, "src", "assets", "logo.svg"), dark=false)
draw_logo(; path=joinpath(@__DIR__, "src", "assets", "logo-dark.svg"), dark=true)
