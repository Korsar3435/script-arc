# Copyright 2013-2024 Lawrence Livermore National Security, LLC and other
# Spack Project Developers. See the top-level COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

# ----------------------------------------------------------------------------
# If you submit this package back to Spack as a pull request,
# please first remove this boilerplate and all FIXME comments.
#
# This is a template package file for Spack.  We've put "FIXME"
# next to all the things you'll want to change. Once you've handled
# them, you can save this file and test your package like this:
#
#     spack install motiv
#
# You can edit this file again by typing:
#
#     spack edit motiv
#
# See the Spack documentation for more information on packaging.
# ----------------------------------------------------------------------------

import os
import subprocess
import shutil


from spack.package import *


class Motiv(CMakePackage):
    """An interactive Qt application to visualize OTF2 trace files."""

    homepage = "https://parcio.github.io/motiv/"
    git = "https://www.github.com/parcio/motiv.git"

    # in compliance with this recommended list: https://spdx.org/licenses/
    license("GPL-3.0-or-later", checked_by="Korsar3435")

    version("main", branch="main", preferred=True, submodules=True)
    version("1.0.0", commit="7ced7e1fbd0a4d4b5340334b488f6e7aae7d0305", submodules=True)

    version("dev", git="https://github.com/Azera5/motiv.git", branch="main+Prototype", submodules=True)
    version("1.0.1", git="https://github.com/Azera5/motiv.git", branch="Tests", submodules=True)

    depends_on("cmake@3.19:", type="build")
    depends_on("otf2", type="link")
    depends_on("qt-base+gui", type="link")

    variant("stats", default=False, description="utility for benchmarking purposes; single file shell script")

    conflicts(
        "+stats",
        when="@1.0.0",
        msg="the initial release (1.0.0) doesn't support stats, please try 1.0.1, which differs only in stats support, or later"
    )

    # as stated in https://en.cppreference.com/w/cpp/compiler_support/20
    conflicts('%gcc@:9', msg="motiv requires full support for C++20, e.g. gcc@10 or later")

    @run_before("build")
    def conf_stats(self):
        spec=self.spec
        prefix=self.prefix
        stats_src_path=self.stage.source_path+'/stats'
        if "+stats" in spec:
            if not os.path.exists(stats_src_path):
                raise Exception('no stats files found')
            elif not os.path.isfile(stats_src_path):
                shutil.copytree(stats_src_path, prefix+'/stats')
            else:
                #raise Exception('depricated version of stats')
                # compatibility for old stats, which is a single file
                stats_new_lines = []
                with open(stats_src_path, 'r') as file:
                    for line in file:
                        if line.startswith('CFG_LOCATION='):
                            # we need a custom config location
                            stats_new_lines.append('CFG_LOCATION='+prefix+'/stats.cfg\n')
                        elif line.startswith('if [ -n "$(whereis -b git'):
                            # git features are not available
                            stats_new_lines.append('if false; then\n')
                        else:
                            # our binary has a new location
                            new_line = line.replace('./build/motiv', './bin/motiv')
                            stats_new_lines.append(new_line)
                with open(stats_src_path, 'w') as file:
                    file.writelines(stats_new_lines)
                shutil.copy(stats_src_path, prefix+'/')
                subprocess.run([prefix+'/stats -c'], input='n', shell=True, text=True)


    def build(self, spec, prefix):
        args = [
            '-S', self.stage.source_path,
            '-B', prefix+'/build'
        ]
        cmake(*args)
