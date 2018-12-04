def lift(lst):
    return map(lambda x: x / (1000000 * 10.0), lst)

res_fib_mj = lift([
    20305532,
    20657833,
    21745872,
    21996125,
    21107893,
    21431538,
    19899185,
    21243951,
    19945987,
    20642236,
])

res_fib_tj = [

]

res_fib_interp = lift([
    121506470,
    125865290,
    131771400,
    128807050,
    125531530,
    124474820,
    125934400,
    129018630,
    126312510,
    122469670,
])

res_fib_c = [
    0.704813,
    0.708246,
    0.730417,
    0.739207,
    0.744555,
    0.726945,
    0.732050,
    0.728166,
    0.728420,
    0.727768
]

res_fib_mincaml =lift([
    5999235,
    5790699,
    5905136,
    5693295,
    5766781,
    5873176,
    5725184,
    5899654,
    5629623,
    5616627
])

res_fib_pypy = [
    1.983286,
    1.955489,
    1.985446,
    1.947740,
    1.926198,
    1.925605,
    1.953368,
    2.016001,
    1.942931,
    1.933935,
    1.938559,
    1.912190,
    1.967927,
    1.953703,
    1.928352,
    1.970905,
    1.972276,
    1.969526,
    1.921205,
    1.930379,
    1.926489,
    1.923669,
    1.947990,
    2.007130,
    1.970266,
    1.972899,
    1.969755,
    1.920823,
    1.946379,
    1.930151,
    1.939653,
    1.946937,
    1.962716,
    2.046868,
    1.963781,
    2.025272,
    2.027073,
    1.917482,
    1.956881,
    1.992815,
    1.983841,
    1.959427,
    1.945685,
    1.909347,
    1.949584,
    1.921101,
    1.960305,
    1.945483,
    1.978631,
    1.962489,
    1.930173,
    1.961204,
    1.944613,
    1.917057,
    1.970445,
    1.954175,
    2.015045,
    1.954330,
    1.930249,
    1.928591,
    1.935888,
    2.170178,
    2.044890,
    2.013413,
    1.954917,
    1.960572,
    1.987767,
    1.939962,
    1.935571,
    2.004981,
    1.935127,
    1.979892,
    1.959907,
    1.950834,
    1.946070,
    1.902476,
    1.967862,
    1.948492,
    1.942017,
    1.982291,
    1.966104,
    1.946195,
    1.941606,
    1.958669,
    1.946341,
    1.931012,
    1.957812,
    1.971041,
    1.976405,
    1.958746,
    1.917028,
    1.933947,
    1.934035,
    1.933464,
    1.962811,
    2.022025,
    2.034830,
    2.014828,
    1.917642,
    1.911211
]