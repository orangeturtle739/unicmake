# https://cmake.org/cmake/help/v3.17/release/3.17.html#variables
# https://cmake.org/cmake/help/latest/variable/CMAKE_CURRENT_FUNCTION_LIST_DIR.html
# That would be ideal, but apparently is too new
set(_THIS_MODULE_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}")

find_package(Python3 COMPONENTS Interpreter REQUIRED)
find_program(BLACK black REQUIRED)
find_program(FLAKE8 flake8 REQUIRED)
find_program(MYPY mypy REQUIRED)
find_program(ISORT isort REQUIRED)

function(unicmake_python_black CONTENT_DIR CONTENT_STAMP OUTVAR FORMAT_TARGET)
    set(DIR ${CMAKE_CURRENT_SOURCE_DIR}/${CONTENT_DIR})
    set(OUT ${CMAKE_CURRENT_BINARY_DIR}/${CONTENT_DIR}/black.stamp)
    set(${OUTVAR} ${OUT} PARENT_SCOPE)
    add_custom_command(
        COMMAND ${BLACK} --check --diff --exclude "" .
        COMMAND touch ${OUT}
        OUTPUT ${OUT}
        WORKING_DIRECTORY ${DIR}
        DEPENDS ${CONTENT_STAMP}
        VERBATIM
    )
    add_custom_target(${FORMAT_TARGET}
        COMMAND ${BLACK} --exclude "" .
        WORKING_DIRECTORY ${DIR}
        VERBATIM
    )
endfunction()

function(unicmake_python_isort CONTENT_DIR CONTENT_STAMP OUTVAR FORMAT_TARGET)
    set(DIR ${CMAKE_CURRENT_SOURCE_DIR}/${CONTENT_DIR})
    set(OUT ${CMAKE_CURRENT_BINARY_DIR}/${CONTENT_DIR}/isort.stamp)
    set(${OUTVAR} ${OUT} PARENT_SCOPE)

    set(CONFIG_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    set(CONFIG_FILE ${CONFIG_DIR}/.isort.cfg)
    add_custom_command(
        COMMAND ${ISORT} --check --settings-path ${CONFIG_DIR} ${DIR}
        COMMAND touch ${OUT}
        OUTPUT ${OUT}
        WORKING_DIRECTORY ${DIR}
        DEPENDS ${CONTENT_STAMP} ${CONFIG_FILE}
        VERBATIM
    )
    add_custom_target(${FORMAT_TARGET}
        COMMAND ${ISORT} --settings-path ${CONFIG_DIR} ${DIR}
        WORKING_DIRECTORY ${DIR}
        VERBATIM
    )
endfunction()

function(unicmake_python_flake8 CONTENT_DIR CONTENT_STAMP OUTVAR)
    set(DIR ${CMAKE_CURRENT_SOURCE_DIR}/${CONTENT_DIR})
    set(OUT ${CMAKE_CURRENT_BINARY_DIR}/${CONTENT_DIR}/flake8.stamp)
    set(${OUTVAR} ${OUT} PARENT_SCOPE)

    set(CONFIG_FILE ${CMAKE_CURRENT_SOURCE_DIR}/.flake8)
    add_custom_command(
        COMMAND ${FLAKE8} --config=${CONFIG_FILE} .
        COMMAND touch ${OUT}
        OUTPUT ${OUT}
        WORKING_DIRECTORY ${DIR}
        DEPENDS ${CONTENT_STAMP} ${CONFIG_FILE}
        VERBATIM
    )
endfunction()

function(unicmake_python_mypy CONTENT_DIR CONTENT_STAMP MYPYPATH_EXTRA OUTVAR)
    set(DIR ${CMAKE_CURRENT_SOURCE_DIR}/${CONTENT_DIR})
    set(OUTDIR ${CMAKE_CURRENT_BINARY_DIR}/${CONTENT_DIR})
    set(OUT ${OUTDIR}/mypy.stamp)
    set(${OUTVAR} ${OUT} PARENT_SCOPE)

    set(CONFIG_FILE ${CMAKE_CURRENT_SOURCE_DIR}/.mypy.ini)
    add_custom_command(
        COMMAND ${CMAKE_COMMAND} -E env MYPYPATH=$ENV{MYPYPATH}:${MYPYPATH_EXTRA} ${MYPY} --config-file ${CONFIG_FILE} --cache-dir ${OUTDIR}/.mypy_cache .
        COMMAND touch ${OUT}
        OUTPUT ${OUT}
        WORKING_DIRECTORY ${DIR}
        DEPENDS ${CONTENT_STAMP} ${CONFIG_FILE}
        VERBATIM
    )
endfunction()

function(unicmake_python_build ROOT SRC MYPYPATH_EXTRA LINT_TARGET FORMAT_TARGET)
    unicmake_content_stamp(${SRC} SRCSTAMP)
    unicmake_python_black(${ROOT} ${SRCSTAMP} BLACK_STAMP ${FORMAT_TARGET}_BLACK)
    unicmake_python_isort(${ROOT} ${SRCSTAMP} ISORT_STAMP ${FORMAT_TARGET}_ISORT)
    unicmake_python_flake8(${ROOT} ${SRCSTAMP} FLAKE8_STAMP)
    unicmake_python_mypy(${ROOT} ${SRCSTAMP} "${MYPYPATH_EXTRA}" MYPY_STAMP)

    add_custom_target(${LINT_TARGET}
        DEPENDS
            ${BLACK_STAMP}
            ${ISORT_STAMP}
            ${FLAKE8_STAMP}
            ${MYPY_STAMP}
    )

    add_dependencies(${FORMAT_TARGET}_ISORT ${FORMAT_TARGET}_ISORT)
    add_custom_target(${FORMAT_TARGET}
        DEPENDS ${FORMAT_TARGET}_ISORT ${FORMAT_TARGET}_BLACK
    )
endfunction()

function(unicmake_setuppy ACTION PACKAGE_NAME OUTVAR)
    set(INSTALL_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/target)
    set(FULL_SITEDIR ${INSTALL_PREFIX}/${SITEDIR})
    set(OUTDIR ${CMAKE_CURRENT_BINARY_DIR}/setup.py)
    set(OUT ${OUTDIR}/${ACTION}.stamp)
    set(${OUTVAR} ${OUT} PARENT_SCOPE)

    # sitecustomize.py is needed due to
    # https://github.com/pypa/setuptools/issues/2612
    # See also:
    # https://github.com/pypa/setuptools/issues/2589
    # https://github.com/pypa/setuptools/commit/cb962021c53b7130bf0a1792f75678efcc0724be#diff-edb74f28afd2515905b8e250003a801b34ace1931df0ea9ade39d10781c7168cR209-R213
    add_custom_command(
        COMMAND rm -rf ${OUTDIR}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTDIR}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${FULL_SITEDIR}
        COMMAND
            ${CMAKE_COMMAND} -E env PYTHONPATH=$ENV{PYTHONPATH}:${FULL_SITEDIR} ${Python3_EXECUTABLE} setup.py ${ACTION} --prefix ${INSTALL_PREFIX}
        COMMAND
            ${CMAKE_COMMAND} -E copy ${_THIS_MODULE_BASE_DIR}/sitecustomize.py ${FULL_SITEDIR}
        COMMAND touch ${OUT}
        OUTPUT ${OUT}
        DEPENDS
            ${UNIBUILD_PYTHON_SETUP_STAMP}
        BYPRODUCTS
            ${INSTALL_PREFIX}
            ${CMAKE_CURRENT_SOURCE_DIR}/dist
            ${CMAKE_CURRENT_SOURCE_DIR}/src/${PACKAGE_NAME}.egg-info
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        VERBATIM
    )
endfunction()

function(unicmake_python)
    cmake_parse_arguments(UNIBUILD_PYTHON "" "PACKAGE_NAME;SETUP_STAMP" "ROOTS" ${ARGN})

    set(SITEDIR lib/python${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}/site-packages)

    # This 2 phase process is to put execute permissions on the pyrun script
    # The extra directory is because COPY can't rename a file
    configure_file(
        ${_THIS_MODULE_BASE_DIR}/pyrun.in
        ${CMAKE_CURRENT_BINARY_DIR}/.unicmake_python/pyrun
        @ONLY
    )
    file(
        COPY ${CMAKE_CURRENT_BINARY_DIR}/.unicmake_python/pyrun
        DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    )

    unicmake_python_build(src src/${UNIBUILD_PYTHON_PACKAGE_NAME} "" lint_src format_src)
    add_custom_target(lint DEPENDS lint_src)
    add_custom_target(format DEPENDS format_src)
    foreach(ROOT ${UNIBUILD_PYTHON_ROOTS})
        unicmake_python_build(${ROOT} ${ROOT} ${CMAKE_CURRENT_SOURCE_DIR}/src lint_${ROOT} format_${ROOT})
        add_dependencies(lint lint_${ROOT})
        add_dependencies(format format_${ROOT})
    endforeach()

    unicmake_setuppy(develop ${UNIBUILD_PYTHON_PACKAGE_NAME} DEVELOP_STAMP)
    add_custom_target(develop DEPENDS ${DEVELOP_STAMP} lint)

    unicmake_setuppy(install ${UNIBUILD_PYTHON_PACKAGE_NAME} INSTALL_STAMP)
    add_custom_target(python_default ALL DEPENDS ${INSTALL_STAMP} lint)

    install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/target/
        DESTINATION ${CMAKE_INSTALL_PREFIX}
        USE_SOURCE_PERMISSIONS
    )
endfunction()
