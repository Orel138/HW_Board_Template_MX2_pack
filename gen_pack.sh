#!/usr/bin/env bash
# Version: 3.1
# Date: 2024-04-17
# This bash script generates a CMSIS Software Pack:
#

set -o pipefail

# Set version of gen pack library
# For available versions see https://github.com/Open-CMSIS-Pack/gen-pack/tags.
# Use the tag name without the prefix "v", e.g., 0.7.0
REQUIRED_GEN_PACK_LIB="0.12.0"

# Set default command line arguments
DEFAULT_ARGS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CMSIS_PACK_ROOT="${CMSIS_PACK_ROOT:-${SCRIPT_DIR}}"

# Extract release metadata from v-prefixed Git tags when building a tagged revision.
CURRENT_TAG="$(git describe --exact-match --tags HEAD 2>/dev/null || true)"
TAG_VERSION=""
TAG_DATE=""
if [[ "${CURRENT_TAG}" == v* ]]; then
  TAG_VERSION="${CURRENT_TAG#v}"
  TAG_DATE="$(git log -1 --date=format:%Y-%m-%d --format=%ad HEAD 2>/dev/null || date -u +%Y-%m-%d)"
fi

# Pack warehouse directory - destination
# Default: ./output
#
# PACK_OUTPUT=./output

# Temporary pack build directory,
# Default: ./build
#
# PACK_BUILD=./build

# Specify directory names to be added to pack base directory
# An empty list defaults to all folders next to this script.
# Default: empty (all folders)
#
PACK_DIRS="
  Descriptors
  Images
"

# Specify file names to be added to pack base directory
# Default: empty
#
PACK_BASE_FILES="
  LICENSE.txt
  STMicroelectronics.nucleo-c5orel_hw-board.pdsc
"

# Specify file names to be deleted from pack build directory
# Default: empty
#
PACK_DELETE_FILES="
  .gitignore
  gen_pack.sh
  README.md
"

# Specify patches to be applied
# Default: empty
#
# PACK_PATCH_FILES="
#     <list patches here>
# "

# Specify addition argument to packchk
# Default: empty
#
# PACKCHK_ARGS=()

# Specify additional dependencies for packchk
# Default: empty
#
PACKCHK_DEPS="
  https://www.keil.com/pack/ARM.CMSIS.pdsc
  https://developer.st.com/st-pack-server/api/v1/pack/STMicroelectronics.stm32c5xx_dfp.pdsc
  https://developer.st.com/st-pack-server/api/v1/pack/STMicroelectronics.button_hw-part.pdsc
  https://developer.st.com/st-pack-server/api/v1/pack/STMicroelectronics.crystal_hw-part.pdsc
  https://developer.st.com/st-pack-server/api/v1/pack/STMicroelectronics.esd_hw-part.pdsc
  https://developer.st.com/st-pack-server/api/v1/pack/STMicroelectronics.led_hw-part.pdsc
  https://developer.st.com/st-pack-server/api/v1/pack/STMicroelectronics.st-link_hw-part.pdsc
"

# Optional: restrict fallback modes for changelog generation
# Default: full
# Values:
# - full      Tag annotations, release descriptions, or commit messages (in order)
# - release   Tag annotations, or release descriptions (in order)
# - tag       Tag annotations only
#
# PACK_CHANGELOG_MODE="<full|release|tag>"

# Specify file patterns to be excluded from the checksum file
# Default: <empty>
# Values:
# - empty          All files packaged are included in the checksum file
# - glob pattern   One glob pattern per line. Files matching a given pattern are excluded
#                  from the checksum file
# - "*"            The * (match all pattern) can be used to skip checksum file creating completely.
# 
# PACK_CHECKSUM_EXCLUDE="
#   <list file patterns here>
# "

#
# custom pre-processing steps
#
# usage: preprocess <build>
#   <build>  The build folder
#
function preprocess() {
  local pack_root="${CMSIS_PACK_ROOT}"
  local web_dir="${pack_root}/.Web"
  local local_dir="${pack_root}/.Local"
  local local_pack_dir="${local_dir}/MyVendor.myhwpart_hw-part"
  local local_pack_url="file://localhost/${local_pack_dir}/"
  local myvendor_release_pack_url="https://github.com/Orel138/HW_Part_Template_MX2_pack/releases/download/v2.0.0/MyVendor.myhwpart_hw-part.2.0.0.pack"
  local myvendor_repo_base_url="https://raw.githubusercontent.com/Orel138/HW_Part_Template_MX2_pack/main"
  local myvendor_pack_archive="${TEMP:-/tmp}/MyVendor.myhwpart_hw-part.2.0.0.pack"

  mkdir -p "${web_dir}"
  cat > "${web_dir}/index.pidx" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<index schemaVersion="1.1.0" xs:noNamespaceSchemaLocation="PackIndex.xsd" xmlns:xs="http://www.w3.org/2001/XMLSchema-instance">
  <vendor>Local</vendor>
  <timestamp>2026-05-02T00:00:00Z</timestamp>
  <pindex>
    <pdsc url="https://www.keil.com/pack/" vendor="ARM" name="CMSIS" version="6.1.0"/>
    <pdsc url="https://developer.st.com/st-pack-server/api/v1/pack/" vendor="STMicroelectronics" name="stm32c5xx_dfp" version="2.0.0"/>
    <pdsc url="https://developer.st.com/st-pack-server/api/v1/pack/" vendor="STMicroelectronics" name="button_hw-part" version="2.0.0"/>
    <pdsc url="https://developer.st.com/st-pack-server/api/v1/pack/" vendor="STMicroelectronics" name="crystal_hw-part" version="2.1.0"/>
    <pdsc url="https://developer.st.com/st-pack-server/api/v1/pack/" vendor="STMicroelectronics" name="esd_hw-part" version="2.1.0"/>
    <pdsc url="https://developer.st.com/st-pack-server/api/v1/pack/" vendor="STMicroelectronics" name="led_hw-part" version="2.3.0"/>
    <pdsc url="https://developer.st.com/st-pack-server/api/v1/pack/" vendor="STMicroelectronics" name="st-link_hw-part" version="2.0.0"/>
  </pindex>
</index>
EOF

  mkdir -p "${local_dir}"
  rm -rf "${local_pack_dir}"

  if curl_download "${myvendor_release_pack_url}" "${myvendor_pack_archive}"; then
    mkdir -p "${local_pack_dir}"
    "${UTILITY_ZIP}" x -y "-o${local_pack_dir}" "${myvendor_pack_archive}" >/dev/null
  else
    mkdir -p "${local_pack_dir}/Descriptors/pinout"
    mkdir -p "${local_pack_dir}/Descriptors/parameters"
    mkdir -p "${local_pack_dir}/Documents"
    curl_download "${myvendor_repo_base_url}/MyVendor.myhwpart_hw-part.pdsc" "${local_pack_dir}/MyVendor.myhwpart_hw-part.pdsc"
    curl_download "${myvendor_repo_base_url}/Descriptors/pinout/myhwparttr_pinout.json" "${local_pack_dir}/Descriptors/pinout/myhwparttr_pinout.json"
    curl_download "${myvendor_repo_base_url}/Descriptors/parameters/myhwparttr_parameters.schema.json" "${local_pack_dir}/Descriptors/parameters/myhwparttr_parameters.schema.json"
    curl_download "${myvendor_repo_base_url}/Descriptors/parameters/myhwparttr_parameters.json" "${local_pack_dir}/Descriptors/parameters/myhwparttr_parameters.json"
  fi

  cat > "${local_dir}/local_repository.pidx" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<index schemaVersion="1.1.0">
  <vendor>local_repository</vendor>
  <timestamp>2026-05-02T00:00:00Z</timestamp>
  <pindex>
    <pdsc url="${local_pack_url}" vendor="MyVendor" name="myhwpart_hw-part" version="2.0.0"/>
  </pindex>
</index>
EOF

  # add custom steps here to be executed
  # before populating the pack build folder
  return 0
}

#
# custom post-processing steps
#
# usage: postprocess <build>
#   <build>  The build folder
#
function postprocess() {
  # add custom steps here to be executed
  # after populating the pack build folder
  # but before archiving the pack into output folder
  if [[ -n "${TAG_VERSION}" ]]; then
    local build="$1"
    local pdsc
    pdsc="$(find "${build}" -maxdepth 1 -name '*.pdsc' -print -quit)"

    if [[ -z "${pdsc}" ]]; then
      echo "gen_pack.sh> Error: No PDSC file found in build folder '${build}'." >&2
      return 1
    fi

    python3 - "${pdsc}" "${TAG_VERSION}" "${TAG_DATE}" <<'PY'
import sys
import xml.etree.ElementTree as ET

pdsc_path, version, release_date = sys.argv[1:]
ns_stm32 = "https://developer.st.com/schemas/stm32cube/1.0.0"
ns_xsi = "http://www.w3.org/2001/XMLSchema-instance"

ET.register_namespace("stm32", ns_stm32)
ET.register_namespace("xsi", ns_xsi)

tree = ET.parse(pdsc_path)
root = tree.getroot()

compat_release = root.find(f"./environments/environment/{{{ns_stm32}}}pack/compatibility/release")
if compat_release is not None:
    compat_release.set("version", version)

releases = root.find("./releases")
if releases is None:
    releases = ET.SubElement(root, "releases")

release_entries = releases.findall("release")
if release_entries and release_entries[0].get("version") == version:
    release_entry = release_entries[0]
else:
    release_entry = ET.Element("release")
    releases.insert(0, release_entry)

release_entry.set("version", version)
release_entry.set("date", release_date)
release_entry.text = f"Release {version}."

if hasattr(ET, "indent"):
    ET.indent(tree, space="  ")

tree.write(pdsc_path, encoding="UTF-8", xml_declaration=True)
PY
  fi

  return 0
}

############ DO NOT EDIT BELOW ###########

# Set GEN_PACK_LIB_PATH to use a specific gen-pack library root
# ... instead of bootstrap based on REQUIRED_GEN_PACK_LIB
if [[ -f "${GEN_PACK_LIB_PATH}/gen-pack" ]]; then
  . "${GEN_PACK_LIB_PATH}/gen-pack"
else
  . <(curl -sL "https://raw.githubusercontent.com/Open-CMSIS-Pack/gen-pack/main/bootstrap")
fi

gen_pack "${DEFAULT_ARGS[@]}" "$@"

exit 0
