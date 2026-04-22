#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2021 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

import sys
from setuptools import setup
from Cython.Build import cythonize

NAME = 'saltwinshell'
DESC = 'Agentless Salt for Windows, compatible with salt-ssh'
PYVER = 'Py3'
if sys.version_info.major == 2:
    PYVER = 'Py2'

# Version info -- read without importing
_locals = {}
with open('saltwinshell/version.py') as fp:
    exec(fp.read(), None, _locals)
VERSION = _locals['version']

setup(name=NAME,
      version=VERSION,
      description=DESC,
      author='nychef',
      author_email='',
      url='https://github.com/nychef/saltwinshell.git',
      classifiers=[
          'Operating System :: OS Independent',
          'Programming Language :: Python',
          'Programming Language :: Python :: 3.10',
          'Development Status :: 5 - Production/Stable',
          ],
      packages=['saltwinshell'],
      install_requires=[
          'paramiko',
          'scp',        
          ],
      data_files=[
          ('saltwinshell',['Salt-Env-{0}-AMD64-{1}.zip'.format(VERSION, PYVER)]),
          ('saltwinshell',['Salt-Env-{0}-x86-{1}.zip'.format(VERSION, PYVER)]),
          ],
      ext_modules=cythonize('saltwinshell/core.pyx', language_level = "3"),
      )
