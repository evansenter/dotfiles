from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

from absl import flags
from absl import logging

import google3
import numpy as np
import tensorflow.compat.v2 as tf
import tensorflow_datasets as tfds
import sonnet.v2 as snt

from google3.learning.deepmind.python.adhoc_import import binary_import
from google3.learning.deepmind.python import config_flags

tf.enable_v2_behavior()

FLAGS = flags.FLAGS