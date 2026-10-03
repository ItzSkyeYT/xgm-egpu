"""The print plan, shared by make_plates.py and make_print_pack.py: the stages, and inside each stage the
batches in the order they are printed (first is printed first). A batch is one plate on the printer."""

# stage folder, title, batches: (file name, what it is, brim on its parts, [(part, copies), ...])
STAGES = [
    ('1-tests', 'Tests', [
        ('1A-tests', 'the four test pieces', False,
         [('coupon', 1), ('coupon_inserts', 1), ('coupon_grommet', 1), ('coupon_rear', 1)]),
    ]),
    ('2-board-and-card', 'Board and card', [
        ('2A-floor-board-rear', "the floor under the board's bracket end, with the bracket holder", False,
         [('floor_rr', 1), ('bracket_holder', 1), ('shim_05', 1), ('shim_10', 1), ('shim_15', 1)]),
        ('2B-floor-board-far', "the floor under the board's far end, with the cradle", False,
         [('floor_fr', 1), ('cradle', 1)]),
    ]),
    ('3-structure-sample', 'Structure sample', [
        ('3A-posts-sample', 'one corner post and one mid post', True,
         [('post_corner', 1), ('post_mid', 1)]),
        ('3B-rear-wall', 'both halves of the rear wall', False,
         [('panel_rear_r', 1), ('panel_rear_l', 1)]),
    ]),
    ('4-final', 'The rest', [
        ('4A-floor-psu-side', 'the two floor pieces under the PSU and the cable bay', False,
         [('floor_rl', 1), ('floor_fl', 1)]),
        ('4B-posts', 'the other six posts', True,
         [('post_corner', 3), ('post_mid', 3)]),
        ('4C-far-wall', 'both halves of the far wall', False,
         [('panel_far_l', 1), ('panel_far_r', 1)]),
        ('4D-psu-side-wall', 'both halves of the wall on the PSU side', False,
         [('panel_left_r', 1), ('panel_left_f', 1)]),
        ('4E-card-side-wall', 'both halves of the wall on the card side', False,
         [('panel_right_r', 1), ('panel_right_f', 1)]),
        ('4F-lid-rear', 'the rear half of the lid', False,
         [('lid_l', 1)]),
        ('4G-lid-far', 'the far half of the lid', False,
         [('lid_r', 1)]),
    ]),
]

# one line per part, for the tree in the README
NOTES = {
    'coupon': 'two identical pieces: jigsaw tab, square peg and wall slot',
    'coupon_inserts': 'three bosses, insert holes of 3.8, 4.0 and 4.2 mm',
    'coupon_grommet': 'three clips, slots of 10.5, 11.5 and 12.5 mm',
    'coupon_rear': 'a slice of the rear wall: cable notch, USB-C hole, port window',
    'floor_rr': 'three of the five board bosses, the holder\'s holes, the grommet clip',
    'bracket_holder': "stands in the board's three small holes, carries the bracket's tab",
    'shim_05': 'shims for the holder\'s arm', 'shim_10': 'shims for the holder\'s arm', 'shim_15': 'shims for the holder\'s arm',
    'floor_fr': 'the other two board bosses',
    'cradle': "under the card's far end",
    'post_corner': 'takes an insert in its top end, for a lid screw',
    'post_mid': 'between two wall panels',
    'panel_rear_r': 'USB-C opening, display-port window, laptop-cable notch',
    'panel_rear_l': 'vents over the cable bay',
    'floor_rl': 'under the cable bay and the near end of the PSU',
    'floor_fl': 'under most of the PSU',
    'panel_far_l': "opening for the PSU's power inlet and switch",
    'panel_far_r': 'exhaust grille for the card',
    'panel_left_r': 'PSU intake grille, rear half',
    'panel_left_f': 'PSU intake grille, far half',
    'panel_right_r': "intake grille for the card's fans, rear half",
    'panel_right_f': "intake grille for the card's fans, far half",
    'lid_l': "with the guides that steady the card's bracket and top edge",
    'lid_r': 'vents only',
}

LID_QUARTERS = ['lid_rl', 'lid_rr', 'lid_fl', 'lid_fr']
SUBDIR_LIDQ = 'lid-quarters-if-bed-under-250mm'
