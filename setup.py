#!/usr/bin/env python

from distutils.core import setup

package_dir = {'': 'src'}

setup(name='virl-utils',
      version='1.0.0',
      url='https://github.com/mthibaut/virl-utils',
      description='Utilities for integrating VIRL with the developer experience',
      author='Maarten Thibaut',
      author_email='mthibaut@cisco.com',
      scripts=[
	      'scripts/virl-dictval',
	      'scripts/virl-ios-login',
	      'scripts/virl-nodes',
	      'scripts/virl-flavors',
	      'scripts/virl-fixroot.sh',
	      'scripts/virl-ios-login-chat',
	      'scripts/virl-node-val',
	      'scripts/virl-images',
	      'scripts/virl-ios-wait',
	      'scripts/virl-ports',
	      'scripts/virl-ios-chat',
	      'scripts/virl-mk-ssh-config',
	      'scripts/virl-subdictval'
      ],
      py_modules=['virl_utils'],
      install_requires=['requests'],

      classifiers=[
         'Development Status :: 3 - Alpha',
         'Topic :: Utilities',
	 'Intended Audience :: System Administrators',
	 'Intended Audience :: Developers',
	 'License :: OSI Approved :: Apache Software License'
      ],
)



