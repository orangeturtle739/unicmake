# https://cmake.org/cmake/help/v3.17/release/3.17.html#variables
# https://cmake.org/cmake/help/latest/variable/CMAKE_CURRENT_FUNCTION_LIST_DIR.html
# That would be ideal, but apparently is too new
set(_THIS_MODULE_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}")

function(unicmake_python)
    cmake_parse_arguments(UNIBUILD_PYTHON "" "PACKAGE_NAME;SETUP_STAMP" "" ${ARGN})

    find_package(Python3 COMPONENTS Interpreter REQUIRED)
    find_program(BLACK black REQUIRED)
    find_program(FLAKE8 flake8 REQUIRED)
    find_program(MYPY mypy REQUIRED)
    find_program(ISORT isort REQUIRED)
    find_program(DIRSTAMP dirstamp REQUIRED)

    set(SITEDIR lib/python${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}/site-packages)
    set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/src/${UNIBUILD_PYTHON_PACKAGE_NAME})

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

    add_custom_target(src_stamp
        ALL
        COMMAND ${DIRSTAMP} ${SRC}
        BYPRODUCTS ${SRC}.stamp
        VERBATIM
    )
    add_custom_command(
        COMMAND ${BLACK} --check --diff --exclude "" .
        COMMAND touch ${CMAKE_CURRENT_SOURCE_DIR}/src/black.stamp
        OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/src/black.stamp
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/src
        DEPENDS ${SRC}.stamp
        VERBATIM
    )
    add_custom_command(
        COMMAND ${ISORT} --check --settings-path ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND touch ${CMAKE_CURRENT_SOURCE_DIR}/src/isort.stamp
        OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/src/isort.stamp
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/src
        DEPENDS
            ${SRC}.stamp
            ${CMAKE_CURRENT_SOURCE_DIR}/.isort.cfg
        VERBATIM
    )
    add_custom_command(
        COMMAND ${FLAKE8} --config=${CMAKE_CURRENT_SOURCE_DIR}/.flake8 .
        COMMAND touch ${CMAKE_CURRENT_SOURCE_DIR}/src/flake8.stamp
        OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/src/flake8.stamp
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/src
        DEPENDS
            ${SRC}.stamp
            ${CMAKE_CURRENT_SOURCE_DIR}/.flake8
        VERBATIM
    )
    add_custom_command(
        COMMAND ${MYPY} --config-file ${CMAKE_CURRENT_SOURCE_DIR}/.mypy.ini -p ${UNIBUILD_PYTHON_PACKAGE_NAME}
        COMMAND touch ${CMAKE_CURRENT_SOURCE_DIR}/src/mypy.stamp
        OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/src/mypy.stamp
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/src
        DEPENDS
            ${SRC}.stamp
            ${CMAKE_CURRENT_SOURCE_DIR}/.mypy.ini
        VERBATIM
    )

    add_custom_target(lint
        DEPENDS
            ${SRC}
            ${CMAKE_CURRENT_SOURCE_DIR}/src/black.stamp
            ${CMAKE_CURRENT_SOURCE_DIR}/src/isort.stamp
            ${CMAKE_CURRENT_SOURCE_DIR}/src/flake8.stamp
            ${CMAKE_CURRENT_SOURCE_DIR}/src/mypy.stamp
        VERBATIM
    )

    set(INSTALL_TOOL ${_THIS_MODULE_BASE_DIR}/install.py)

    add_custom_command(
        COMMAND
            ${Python3_EXECUTABLE} ${INSTALL_TOOL} --prefix ${CMAKE_CURRENT_BINARY_DIR}/target --python ${Python3_EXECUTABLE} --site-packages-dir ${SITEDIR}
        COMMAND touch ${CMAKE_CURRENT_SOURCE_DIR}/src/install.stamp
        OUTPUT touch ${CMAKE_CURRENT_SOURCE_DIR}/src/install.stamp
        DEPENDS
            lint
            ${UNIBUILD_PYTHON_SETUP_STAMP}
        BYPRODUCTS
            ${CMAKE_CURRENT_BINARY_DIR}/target
            ${CMAKE_CURRENT_SOURCE_DIR}/dist
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        VERBATIM
    )

    add_custom_target(build_python
        ALL
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/install.stamp
        VERBATIM
    )

    add_custom_command(
        COMMAND
            ${Python3_EXECUTABLE} ${INSTALL_TOOL} --prefix ${CMAKE_CURRENT_BINARY_DIR}/target --python ${Python3_EXECUTABLE} --site-packages-dir ${SITEDIR} --develop
        COMMAND touch ${CMAKE_CURRENT_SOURCE_DIR}/src/develop.stamp
        OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/src/develop.stamp
        DEPENDS
            ${UNIBUILD_PYTHON_SETUP_STAMP}
        BYPRODUCTS
            ${CMAKE_CURRENT_BINARY_DIR}/target
            ${CMAKE_CURRENT_SOURCE_DIR}/dist
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        VERBATIM
    )

    add_custom_target(develop
        DEPENDS
            ${CMAKE_CURRENT_SOURCE_DIR}/src/develop.stamp
            lint
        VERBATIM
    )

    add_custom_target(format
        COMMAND ${BLACK} --exclude "" .
        COMMAND ${ISORT} --apply --settings-path ${CMAKE_CURRENT_SOURCE_DIR}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/src
        VERBATIM
    )

    install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/target/
        DESTINATION ${CMAKE_INSTALL_PREFIX}
        USE_SOURCE_PERMISSIONS
    )
endfunction()
