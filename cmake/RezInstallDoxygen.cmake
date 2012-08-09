#
# rez_install_doxygen
#
# Macro for building and installing doxygen files for rez projects. Take special note of the
# DOXYPY option if you want to build docs for python source.
#
# Usage:
# rez_install_doxygen(
#	<label>
#	FILES <files>
#	DESTINATION <rel_install_dir>
#	[DOXYFILE <doxyfile>]
#	[DOXYDIR <dir>]
#   [FORCE]
#	[DOXYPY]
# )
#
# <label>: This becomes the name of this cmake target. Eg 'doc'.
# DESTINATION: Relative path to install resulting docs to. Typically Doxygen will create a 
# directory (often 'html'), which is installed into <install_path>/<rel_install_dir>/html.
# DOXYFILE: The doxygen config file to use. If unspecified, Rez will use its own default config.
# DOXYDIR: The directory the docs will be generated in, defaults to 'html'. You only need to set
# this if you're generating non-html output (for eg, by setting GENERATE_HTML=NO in a custom Doxyfile).
# FORCE: Normally docs are not installed unless a central installation is taking place - set this
# arg to force doc building and installation always.
# DOXYPY: At the time of writing, Doxygen does not have good python support. A separate, GPL project
# called 'doxypy' (http://code.foosel.org/doxypy) can be used to fix this - it lets you write 
# doxygen-style comments in python docstrings, and extracts them correctly. Doxypy cannot be shipped
# with Rez since its license is incompatible - in order to use it, Rez expects you to install it 
# yourself, and then make it available by binding it to Rez (as you would any 3rd party software) 
# as a package called 'doxypy', with the doxypy.py file in the package root. Once you've done this,
# and you specify the DOXYPY option, you get complete python Doxygen support (don't forget to include
# the doxypy package as a build_requires). You can then comment your python code in doxygen style, 
# like so:
#
# def myFunc(foo):
#   """
#   @param foo The foo.
#   @return Something foo-like.
#   """
#
# Note: Consider adding a rez-help entry to your package.yaml like so:
# help: firefox file://!ROOT!/<DESTINATION>/<DOXYDIR>/index.html
# Then, users can just go "rez-help <pkg>", and the doxygen help will appear.
#

if(NOT REZ_BUILD_ENV)
	message(FATAL_ERROR "RezInstallDoxygen requires that RezBuild have been included beforehand.")
endif(NOT REZ_BUILD_ENV)

FIND_PACKAGE(Doxygen)
if(NOT DOXYGEN_EXECUTABLE)
	message(FATAL_ERROR "RezInstallDoxygen cannot find Doxygen.")
endif(NOT DOXYGEN_EXECUTABLE)


INCLUDE(Utils)


macro (rez_install_doxygen)

	parse_arguments(INSTDOX "FILES;DESTINATION;DOXYFILE;DOXYDIR" "FORCE;DOXYPY" ${ARGN})

	list(GET INSTDOX_DEFAULT_ARGS 0 label)
	if(NOT label)
		message(FATAL_ERROR "need to specify a label in call to rez_install_doxygen")
	endif(NOT label)

	list(GET INSTDOX_DESTINATION 0 dest_dir)
	if(NOT dest_dir)
		message(FATAL_ERROR "need to specify DESTINATION in call to rez_install_doxygen")
	endif(NOT dest_dir)

	if(NOT INSTDOX_FILES)
		message(FATAL_ERROR "no files listed in call to rez_install_doxygen")
	endif(NOT INSTDOX_FILES)

	list(GET INSTDOX_DOXYFILE 0 doxyfile)
	if(NOT doxyfile)
		set(doxyfile $ENV{REZ_PATH}/template/Doxyfile)
	endif(NOT doxyfile)

	list(GET INSTDOX_DOXYDIR 0 doxydir)
	if(NOT doxydir)
		set(doxydir html)
	endif(NOT doxydir)

	set(_filter_source_files "")
	set(_input_filter "")
	set(_opt_output_java "")
	set(_extract_all "")	
	if(INSTDOX_DOXYPY)
		find_file(DOXYPY_SRC doxypy.py $ENV{REZ_DOXYPY_ROOT})
		if(DOXYPY_SRC)
			set(_filter_source_files "FILTER_SOURCE_FILES = YES")
			set(_input_filter "INPUT_FILTER = \"python ${DOXYPY_SRC}\"")
			set(_opt_output_java "OPTIMIZE_OUTPUT_JAVA = YES")
			set(_extract_all "EXTRACT_ALL = YES")
		else(DOXYPY_SRC)
			message(FATAL_ERROR "Cannot locate doxypy.py - you probably need to supply doxypy as a Rez package, see the documentation in <rez_install>/cmake/RezInstallDoxygen.cmake for more info.")
		endif(DOXYPY_SRC)
	endif(INSTDOX_DOXYPY)

	SET(_REZ_YAMLQ $ENV{REZ_PATH}/bin/_rez_query_yaml --filepath=${CMAKE_SOURCE_DIR}/package.yaml )
	EXECUTE_PROCESS(COMMAND ${_REZ_YAMLQ} --print-name OUTPUT_VARIABLE _proj_name OUTPUT_STRIP_TRAILING_WHITESPACE)
	EXECUTE_PROCESS(COMMAND ${_REZ_YAMLQ} --print-version OUTPUT_VARIABLE _proj_ver OUTPUT_STRIP_TRAILING_WHITESPACE)
	EXECUTE_PROCESS(COMMAND ${_REZ_YAMLQ} --print-desc OUTPUT_VARIABLE _proj_desc OUTPUT_STRIP_TRAILING_WHITESPACE)
	string(REPLACE "\n" " " _proj_desc2 ${_proj_desc})

	add_custom_command(
		OUTPUT ${dest_dir}/Doxyfile
		COMMAND ${CMAKE_COMMAND} -E make_directory ${dest_dir}
		COMMAND ${CMAKE_COMMAND} -E copy ${doxyfile} ${dest_dir}/Doxyfile
		COMMAND echo PROJECT_NAME = \"${_proj_name}\" >> ${dest_dir}/Doxyfile
		COMMAND echo PROJECT_NUMBER = \"${_proj_ver}\" >> ${dest_dir}/Doxyfile
		COMMAND echo PROJECT_BRIEF = \"${_proj_desc2}\" >> ${dest_dir}/Doxyfile
		COMMAND echo ${_filter_source_files} >> ${dest_dir}/Doxyfile
		COMMAND echo ${_input_filter} >> ${dest_dir}/Doxyfile
		COMMAND echo ${_opt_output_java} >> ${dest_dir}/Doxyfile
		COMMAND echo ${_extract_all} >> ${dest_dir}/Doxyfile
		COMMAND echo INPUT = ${INSTDOX_FILES} >> ${dest_dir}/Doxyfile
		COMMENT "Generating Doxyfile ${dest_dir}/Doxyfile..."
		VERBATIM
	)

	add_custom_target(${label}
		DEPENDS ${dest_dir}/Doxyfile
		#COMMAND ${DOXYGEN_EXECUTABLE}
		COMMAND doxygen
		WORKING_DIRECTORY ${dest_dir}
		COMMENT "Generating doxygen content in ${dest_dir}/${doxydir}..."
	)

	if(CENTRAL OR INSTDOX_FORCE)
		# only install docs when installing centrally
		add_custom_target(_install_${label} ALL DEPENDS ${label})
		install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${dest_dir}/${doxydir} DESTINATION ${dest_dir})
	endif(CENTRAL OR INSTDOX_FORCE)

endmacro (rez_install_doxygen)