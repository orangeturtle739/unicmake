cmake_minimum_required(VERSION 3.16.3)

find_program(DIRSTAMP dirstamp REQUIRED)

function(unicmake_touch FILE)
    add_custom_command(
        COMMAND touch ${FILE}
        OUTPUT ${FILE}
        VERBATIM
    )
endfunction()

function(unicmake_content_stamp DIR OUTVAR)
    set(OUT ${CMAKE_CURRENT_BINARY_DIR}/${DIR}/content.stamp)
    set(${OUTVAR} ${OUT} PARENT_SCOPE)
    string(MAKE_C_IDENTIFIER ${OUT} TARGET)
    get_filename_component(OUTDIR ${OUT} DIRECTORY)
    add_custom_target(${TARGET}
        ALL
        COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTDIR}
        COMMAND ${DIRSTAMP} ${CMAKE_CURRENT_SOURCE_DIR}/${DIR} ${OUT}
        BYPRODUCTS ${OUT}
        VERBATIM
    )
endfunction()

include(${CMAKE_CURRENT_LIST_DIR}/python/python.cmake)
