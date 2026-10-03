"""Where everything lives. Every script in this folder takes its paths from here."""
import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
CASE = os.path.dirname(TOOLS)
SCAD = os.path.join(CASE, 'xgm-lite-frame.scad')                  # the model: everything else is made from it
MODEL_3MF = os.path.join(CASE, 'xgm-lite-frame-assembled.3mf')    # the whole case assembled, to look at
BUILD = os.path.join(CASE, 'build')                               # what the scripts make on the way
STL = os.path.join(BUILD, 'stl')                                  #   every part, laid out for the bed
ASSEMBLED = os.path.join(BUILD, 'assembled')                      #   every part where it sits in the case
PLATES = os.path.join(BUILD, 'plates')                            #   one OrcaSlicer project per batch
WEIGHTS = os.path.join(BUILD, 'weights.json')                     #   what each part and batch really takes: grams, minutes
DOCS = os.path.join(CASE, 'docs')                                 # dimensions, floor plans, pictures
IMG = os.path.join(DOCS, 'img')
PACK = os.path.join(CASE, 'print-pack')                           # what goes to the printer
