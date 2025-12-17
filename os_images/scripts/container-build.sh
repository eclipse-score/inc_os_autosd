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

#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${BUILDDIR}" ]; then
	BUILDDIR="${SCRIPT_DIR}/../outputs"
fi

if [ -z "${AIB_SCRIPT_URL}" ]; then
	AIB_SCRIPT_URL='https://gitlab.com/CentOS/automotive/src/automotive-image-builder/-/raw/main/auto-image-builder.sh?ref_type=heads'
fi

mkdir -p ${BUILDDIR}

if [ ! -f ${SCRIPT_DIR}/auto-image-builder.sh ]; then
	curl \
	-L \
	-o ${SCRIPT_DIR}/auto-image-builder.sh \
	${AIB_SCRIPT_URL}
fi

chmod +x ${SCRIPT_DIR}/auto-image-builder.sh
chown $(logname) reference_integration/scripts/auto-image-builder.sh

${SCRIPT_DIR}/auto-image-builder.sh $@

sudo chown $(logname) ${!#}
