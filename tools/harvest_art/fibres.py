"""Five field growth stages for cotton bolls and the serrated leaves of ramie."""
from math import cos, sin
from crops import GREEN, YOUNG, STEM, UP, PHYLLOTAXIS, ROOT, Model, bulb, direction, leaf, rgb, shoot, vec, write_glb


def plant(model, phase, cotton):
    if phase == 0:
        shoot(model, .11)
        return
    height = (.35 + phase * .16) * (1 if cotton else 1.12)
    for stem in range(3 if not cotton else 1):
        base = direction(stem * 2.1) * stem * .054
        tip = base + vec(.038, height, .045)
        model.tube([base, tip], .017, STEM, 6)
        for node in range(3 + phase):
            t = .23 + node * .10
            a = node * PHYLLOTAXIS + stem
            twig = base + (tip - base) * t
            bud = twig + direction(a) * (.12 + node % 2 * .07) + UP * .11
            model.tube([twig, bud], .009, STEM, 5)
            leaf(model, bud, a, .19, .052, .098, .044, (GREEN, YOUNG),
                 teeth=.075 if not cotton else .02, grid=(8, 12))
            if cotton and phase >= 2 and node % 2 == 0:
                for k in range(4):
                    p = bud + vec(cos(k * 1.57) * .042, .035, sin(k * 1.57) * .042)
                    colors = ('bbb184', 'fff5db') if phase == 4 else ('879653', 'b1b66f')
                    bulb(model, p, vec(.061, .066, .055), rgb(colors[0]), rgb(colors[1]), segments=10)


if __name__ == '__main__':
    for crop in ('cotton', 'ramie'):
        stages = {}
        for phase in range(5):
            model = Model()
            plant(model, phase, crop == 'cotton')
            stages[f'Phase{phase}'] = model
        write_glb(ROOT / 'assets' / 'harvest' / (crop + '.glb'), stages)
