# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************
def is_integer_literal(value):
    if not value:
        return False
    if value[0] == "-":
        value = value[1:]
    return value.isdigit()

def normalize_bool_attr(attr_name, value):
    if value == "true" or value == "True":
        return "true"
    if value == "false" or value == "False":
        return "false"
    fail("{} must be \"true\" or \"false\"".format(attr_name))

def indent(spaces):
    return " " * spaces

def render_bool_field(indent_size, attr_name, field_name, value):
    if not value:
        return ""
    return "{}{}: {}\n".format(
        indent(indent_size),
        field_name,
        normalize_bool_attr(attr_name, value),
    )

def render_string_field(indent_size, field_name, value):
    if value == None or value == "":
        return ""
    return "{}{}: {}\n".format(indent(indent_size), field_name, value)

def render_nullable_string_field(indent_size, field_name, value):
    if not value:
        return ""
    if value == "null":
        return "{}{}: null\n".format(indent(indent_size), field_name)
    return render_string_field(indent_size, field_name, value)

def render_list_field(indent_size, field_name, values):
    if not values:
        return ""

    rendered = "{}{}:\n".format(indent(indent_size), field_name)
    rendered += "".join(
        [
            "{}- {}\n".format(indent(indent_size + 2), value)
            for value in values
        ],
    )
    return rendered

def parse_key_value(attr_name, field):
    parts = field.split("=", 1)
    if len(parts) != 2 or not parts[0]:
        fail("{} entries must use key=value strings: {}".format(attr_name, field))
    return parts

def split_csv(value):
    if not value:
        return []
    return value.split(",")

def validate_integer_field(attr_name, key, value):
    if not is_integer_literal(value):
        fail("{} field '{}' must be an integer".format(attr_name, key))

def field_error(attr_name, key, expected):
    fail("unsupported {} field '{}'; expected {}".format(attr_name, key, expected))

def require_unique(values, attr_name, key):
    if key in values:
        fail("duplicate {} field '{}'".format(attr_name, key))
