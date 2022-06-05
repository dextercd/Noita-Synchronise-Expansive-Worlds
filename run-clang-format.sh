#!/bin/sh

find native \( -name \*.cpp -o -name \*.hpp \) -exec clang-format -i {} +
