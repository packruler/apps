#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

DEFAULT_CHART_RELEASER_VERSION=v1.2.1

show_help() {
cat << EOF
Usage: $(basename "$0") <options>
    -h, --help               Display help
    -v, --version            The chart-releaser version to use (default: $DEFAULT_CHART_RELEASER_VERSION)"
        --config             The path to the chart-releaser config file
    -d, --charts-dir         The charts directory (default: charts)
    -u, --charts-repo-url    The GitHub Pages URL to the charts repo (default: https://<owner>.github.io/<repo>)
    -o, --owner              The repo owner
    -r, --repo               The repo name
    -p, --production         Enables uploading releases to github releases
    -s, --standalone         Disables Chart Releaser and Catalog Validation, for local generation
EOF
}

main() {
    local version="$DEFAULT_CHART_RELEASER_VERSION"
    local config=
    local standalone=
    local charts_dir=charts/**
    local owner=
    local repo=
    local production=
    local charts_repo_url=
    local token=${CR_TOKEN:-false}
    local parthreads=$(($(nproc) * 2))

    parse_command_line "$@"
    if [ "${token}" == "false" ]; then
        echo "env #CR_TOKEN not found, defaulting to production=false"
        production="false"
    fi

    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    pushd "$repo_root" > /dev/null

    echo 'Looking up latest tag...'
    local latest_tag
    latest_tag=$(lookup_latest_tag)

    echo "Discovering changed charts since '$latest_tag'..."
    local changed_charts=()
    readarray -t changed_charts <<< "$(lookup_changed_charts "$latest_tag")"
    # copy_general_docs
    if [[ -n "${changed_charts[*]}" ]]; then

        prep_helm

        parallel -j ${parthreads} chart_runner '2>&1' ::: ${changed_charts[@]}
        echo "Starting post-processing"
        pre_commit
        validate_catalog
        if [ "${production}" == "true" ]; then
        gen_dh_cat
        upload_catalog
        upload_dhcatalog
        fi
    else
        echo "Nothing to do. No chart changes detected."
    fi

    popd > /dev/null
}

chart_runner(){
  if [[ -d "${1}" ]]; then
      echo "Start processing ${1} ..."
      chartversion=$(cat ${1}/Chart.yaml | grep "^version: " | awk -F" " '{ print $2 }')
      chartname=$(basename ${1})
      train=$(basename $(dirname "${1}"))
      SCALESUPPORT=$(cat ${1}/Chart.yaml | yq '.annotations."truecharts.org/SCALE-support"' -r)
      helm dependency update "${1}" --skip-refresh || (sleep 10 && helm dependency update "${1}" --skip-refresh) || (sleep 10 && helm dependency update "${1}" --skip-refresh)
      helm_sec_scan "${1}" "${chartname}" "$train" "${chartversion}" || echo "helm-chart security-scan failed..."
      container_sec_scan "${1}" "${chartname}" "$train" "${chartversion}" || echo "container security-scan failed..."
      sec_scan_cleanup "${1}" "${chartname}" "$train" "${chartversion}" || echo "security-scan cleanup failed..."
      sync_tag "${1}" "${chartname}" "$train" "${chartversion}" || echo "Tag sync failed..."
      create_changelog "${1}" "${chartname}" "$train" "${chartversion}" || echo "changelog generation failed..."
      generate_docs "${1}" "${chartname}" "$train" "${chartversion}" || echo "Docs generation failed..."
      #copy_docs "${1}" "${chartname}" "$train" "${chartversion}" || echo "Docs Copy failed..."
      #package_chart "${1}"
      if [[ "${SCALESUPPORT}" == "true" ]]; then
        clean_apps "${1}" "${chartname}" "$train" "${chartversion}"
        copy_apps "${1}" "${chartname}" "$train" "${chartversion}"
        patch_apps "${1}" "${chartname}" "$train" "${chartversion}"
        include_questions "${1}" "${chartname}" "$train" "${chartversion}"
        clean_catalog "${1}" "${chartname}" "$train" "${chartversion}"
      else
        echo "Skipping chart ${1}, no correct SCALE compatibility layer detected"
      fi
  else
      echo "Chart '${1}' no longer exists in repo. Skipping it..."
  fi
  echo "Done processing ${1} ..."
}
export -f chart_runner

include_questions(){
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    local target="catalog/${train}/${chartname}/${chartversion}"
    echo "Including standardised questions.yaml includes for: ${chartname}"

    # Replace # Include{global} with the standard global codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{global}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/global.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{groups} with the standard groups codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{groups}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/groups.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{fixedEnv} with the standard fixedEnv codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{fixedEnv}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/fixedEnv.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

     # Replace # Include{controllerExpert} with the standard controllerExpert codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{controllerExpert}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/controllerExpert.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{containerConfig} with the standard containerConfig codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{containerConfig}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/containerConfig.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{serviceSelector} with the standard serviceSelector codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{serviceSelector}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/serviceSelector.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{serviceExpert} with the standard serviceExpert codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{serviceExpert}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/serviceExpert.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{serviceList} with the standard serviceList codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{serviceList}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/serviceList.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{persistenceBasic} with the standard persistenceBasic codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{persistenceBasic}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/persistenceBasic.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{persistenceAdvanced} with the standard persistenceAdvanced codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{persistenceAdvanced}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/persistenceAdvanced.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{persistenceList} with the standard persistenceList codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{persistenceList}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/persistenceList.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{security} with the standard security codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{security}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/security.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{securityContextAdvanced} with the standard securityContextAdvanced codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{securityContextAdvanced}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/securityContextAdvanced.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{podSecurityContextAdvanced} with the standard podSecurityContextAdvanced codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{podSecurityContextAdvanced}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/podSecurityContextAdvanced.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{ingressDefault} with the standard ingressDefault codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{ingressDefault}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/ingressDefault.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{ingressTLS} with the standard ingressTLS codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{ingressTLS}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/ingressTLS.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{ingressTraefik} with the standard ingressTraefik codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{ingressTraefik}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/ingressTraefik.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{ingressExpert} with the standard ingressExpert codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{ingressExpert}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/ingressExpert.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{ingressList} with the standard ingressList codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{ingressList}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/ingressList.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{addons} with the standard addons codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{addons}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/addons.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{themePark} with the standard themePark codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{themePark}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/themePark.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{metrics} with the standard metrics codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{metrics}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/metrics.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{metrics3m} with the standard metrics3m codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{metrics3m}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/metrics3m.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{metrics60m} with the standard metrics60m codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{metrics60m}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/metrics60m.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{prometheusRule} with the standard prometheusRule codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{prometheusRule}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/prometheusRule.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{advanced} with the standard advanced codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{advanced}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/advanced.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    # Replace # Include{resources} with the standard resources codesnippet
    awk 'NR==FNR { a[n++]=$0; next }
    /# Include{resources}/ { for (i=0;i<n;++i) print a[i]; next }
    1' templates/questions/resources.yaml ${target}/questions.yaml > "tmp${chartname}" && mv "tmp${chartname}" ${target}/questions.yaml

    }
export -f include_questions

clean_catalog() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    cd catalog/${train}/${chartname}
    local majorversions=$( (find . -mindepth 1 -maxdepth 1 -type d  \( ! -iname ".*" \) | sed 's|^\./||g') | sort -Vr | cut -c1 | uniq)
    echo "Removing old versions for: ${chartname}"
    for majorversion in ${majorversions}; do
      local maxofmajor=$( (find . -mindepth 1 -maxdepth 1 -type d  \( -iname "${majorversion}.*" \) | sed 's|^\./||g') | sort -Vr | head -n1 )
      local rmversions=$( (find . -mindepth 1 -maxdepth 1 -type d  \( -iname "${majorversion}.*" \) \( ! -iname "${maxofmajor}" \) | sed 's|^\./||g') | sort -Vr )
      rm -Rf ${rmversions}
    done
    cd -
    }
export -f clean_catalog

gen_dh_cat() {
    rm -rf dh_catalog/*.*
    rm -rf dh_catalog/*
    cp -rf catalog/* dh_catalog
    cd dh_catalog
    find ./ -type f -name *.yaml -exec sed -i 's/tccr.io/dh.tccr.io/gI' {} \;
    cd -
   }
export -f gen_dh_cat

# Designed to ensure the appversion in Chart.yaml is in sync with the primary App tag if found
sync_tag() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    echo "Attempting to sync primary tag with appversion for: ${chartname}"
    local tag="$(cat ${chart}/values.yaml | grep '^  tag: ' | awk -F" " '{ print $2 }' | head -1)"
    tag="${tag%%@*}"
    tag="${tag:-auto}"
    tag=$(echo $tag | sed "s/release-//g")
    tag=$(echo $tag | sed "s/release_//g")
    tag=$(echo $tag | sed "s/version-//g")
    tag=$(echo $tag | sed "s/version_//g")
    tag="${tag#*V.}"
    tag="${tag#*v-}"
    tag="${tag#*v}"
    tag="${tag%-*}"
    tag="${tag:0:10}"
    tag="${tag%-}"
    tag="${tag%_}"
    tag="${tag%.}"
    sed -i -e "s|appVersion: .*|appVersion: \"${tag}\"|" "${chart}/Chart.yaml"
    }
export -f sync_tag

helm_sec_scan() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    echo "Scanning helm security for ${chartname}"
    mkdir -p ${chart}/render
    rm -rf ${chart}/security.md || echo "removing old security.md file failed..."
    cat templates/security.tpl >> ${chart}/security.md
    echo "" >> ${chart}/security.md
    helm template ${chart} --output-dir ${chart}/render > /dev/null
    trivy config -f template --template "@./templates/trivy-config.tpl" -o ${chart}/render/tmpsec${chartname}.md ${chart}/render
    cat ${chart}/render/tmpsec${chartname}.md >> ${chart}/security.md
    rm -rf ${chart}/render/tmpsec${chartname}.md || true
    echo "" >> ${chart}/security.md
    }
    export -f helm_sec_scan

container_sec_scan() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    echo "Scanning container security for ${chartname}"
    echo "## Containers" >> ${chart}/security.md
    echo "" >> ${chart}/security.md
    echo "##### Detected Containers" >> ${chart}/security.md
    echo "" >> ${chart}/security.md
    find ./${chart}/render/ -name '*.yaml' -type f -exec cat {} \; | grep image: | sed "s/image: //g" | sed "s/\"//g" >> ${chart}/render/containers.tmp
    cat ${chart}/render/containers.tmp >> ${chart}/security.md
    echo "" >> ${chart}/security.md
    echo "##### Scan Results" >> ${chart}/security.md
    echo "" >> ${chart}/security.md
    for container in $(cat ${chart}/render/containers.tmp); do
      echo "processing container: ${container}"
      echo "" >> ${chart}/security.md
      trivy image -f template --template "@./templates/trivy-container.tpl" -o ${chart}/render/tmpsec${chartname}.md "${container}"
      cat ${chart}/render/tmpsec${chartname}.md >> ${chart}/security.md
      rm -rf ${chart}/render/tmpsec${chartname}.md || true
      echo "" >> ${chart}/security.md
    done

    }
    export -f container_sec_scan

sec_scan_cleanup() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    rm -rf ${chart}/render
    sed -i 's/ghcr.io/tccr.io/g' ${chart}/security.md
    }
    export -f sec_scan_cleanup

pre_commit() {
    if [[ -z "$standalone" ]]; then
      echo "Running pre-commit test-and-cleanup..."
       pre-commit run --all ||:
      # Fix sh files to always be executable
      find . -name '*.sh' | xargs chmod +x
    fi
    }
    export -f pre_commit

create_changelog() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    local prevversion="$(git tag -l "${chartname}-*" --sort=-v:refname  | head -n 1)"
    if [[ -z "$standalone" ]]; then
        echo "Generating changelogs for: ${chartname}"
        # SCALE "Changelog" containing only last change
        git-chglog --next-tag ${chartname}-${chartversion} --tag-filter-pattern ${chartname} --path ${chart} -o ${chart}/app-changelog.md ${chartname}-${chartversion}
        # Append SCALE changelog to actual changelog

        if [[ -f "${chart}/CHANGELOG.md" ]]; then
           true
        else
           touch ${chart}/CHANGELOG.md
        fi
        sed -i '1d' ${chart}/CHANGELOG.md
        cat ${chart}/app-changelog.md | cat - ${chart}/CHANGELOG.md > temp && mv temp ${chart}/CHANGELOG.md
        sed -i '1s/^/# Changelog<br>\n\n/' ${chart}/CHANGELOG.md
        rm ${chart}/app-changelog.md || echo "changelog not found..."
    fi
    }
    export -f create_changelog

copy_general_docs() {
    yes | cp -rf index.yaml docs/index.yaml 2>/dev/null || :
    yes | cp -rf .github/README.md docs/index.md 2>/dev/null || :
    sed -i '1s/^/---\nhide:\n  - navigation\n  - toc\n---\n/' docs/index.md
    sed -i 's~<!-- INSERT-DISCORD-WIDGET -->~<iframe src="https://discord.com/widget?id=830763548678291466\&theme=dark" width="350" height="500" allowtransparency="true" frameborder="0" sandbox="allow-popups allow-popups-to-escape-sandbox allow-same-origin allow-scripts"></iframe>~g' docs/index.md
    yes | cp -rf .github/CODE_OF_CONDUCT docs/about/code_of_conduct.md 2>/dev/null || :
    yes | cp -rf .github/CONTRIBUTING docs/development/contributing.md 2>/dev/null || :
    yes | cp -rf .github/SUPPORT.md docs/manual/SUPPORT.md 2>/dev/null || :
    yes | cp -rf LICENSE docs/about/legal/LICENSE.md 2>/dev/null || :
    sed -i '1s/^/# License<br>\n\n/' docs/about/legal/LICENSE.md
    yes | cp -rf NOTICE docs/about/legal/NOTICE.md 2>/dev/null || :
    sed -i '1s/^/# NOTICE<br>\n\n/' docs/about/legal/NOTICE.md
    }
    export -f copy_general_docs

generate_docs() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    if [[ -z "$standalone" ]]; then
         echo "Generating Docs"
         if [ "${chartname}" == "common" ]; then
             helm-docs \
                 --ignore-file=".helmdocsignore" \
                 --output-file="README.md" \
                 --template-files="/__w/apps/apps/templates/docs/common-README.md.gotmpl" \
                 --chart-search-root="${chart}"
             helm-docs \
                 --ignore-file=".helmdocsignore" \
                 --output-file="helm-values.md" \
                 --template-files="/__w/apps/apps/templates/docs/common-helm-values.md.gotmpl" \
                 --chart-search-root="${chart}"
         else
             helm-docs \
                 --ignore-file=".helmdocsignore" \
                 --output-file="README.md" \
                 --template-files="/__w/apps/apps/templates/docs/README.md.gotmpl" \
                 --chart-search-root="${chart}"
             helm-docs \
                 --ignore-file=".helmdocsignore" \
                 --output-file="CONFIG.md" \
                 --template-files="/__w/apps/apps/templates/docs/CONFIG.md.gotmpl" \
                 --chart-search-root="${chart}"
             helm-docs \
                 --ignore-file=".helmdocsignore" \
                 --output-file="helm-values.md" \
                 --template-files="/__w/apps/apps/templates/docs/helm-values.md.gotmpl" \
                 --chart-search-root="${chart}"
         fi
    fi
    }
    export -f generate_docs


copy_docs() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    echo "Copying docs for: ${chart}"
    if [ "${chartname}" == "common" ]; then
        mkdir -p docs/apps/common || :
        yes | cp -rf charts/library/common/README.md  docs/apps/common/index.md 2>/dev/null || :
        yes | cp -rf charts/library/common/helm-values.md  docs/apps/common/helm-values.md 2>/dev/null || :
    else
        mkdir -p docs/apps/${train}/${chartname} || echo "app path already exists, continuing..."
        yes | cp -rf ${chart}/README.md docs/apps/${train}/${chartname}/index.md 2>/dev/null || :
        yes | cp -rf ${chart}/CHANGELOG.md docs/apps/${train}/${chartname}/CHANGELOG.md 2>/dev/null || :
        yes | cp -rf ${chart}/security.md docs/apps/${train}/${chartname}/security.md 2>/dev/null || :
        yes | cp -rf ${chart}/CONFIG.md docs/apps/${train}/${chartname}/CONFIG.md 2>/dev/null || :
        yes | cp -rf ${chart}/helm-values.md docs/apps/${train}/${chartname}/helm-values.md 2>/dev/null || :
        rm docs/apps/${train}/${chartname}/LICENSE.md 2>/dev/null || :
        yes | cp -rf ${chart}/LICENSE docs/apps/${train}/${chartname}/LICENSE.md 2>/dev/null || :
        sed -i '1s/^/# License<br>\n\n/' docs/apps/${train}/${chartname}/LICENSE.md 2>/dev/null || :
    fi
    }
    export -f copy_docs

prep_helm() {
    if [[ -z "$standalone" ]]; then
    helm repo add truecharts-old https://truecharts.org
    helm repo add truecharts https://charts.truecharts.org
    helm repo add truecharts-library https://library-charts.truecharts.org
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add metallb https://metallb.github.io/metallb
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus https://prometheus-community.github.io/helm-charts
    helm repo add amd-gpu-helm https://radeonopencompute.github.io/k8s-device-plugin/
    helm repo update
    fi
    }
    export -f prep_helm

clean_apps() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    echo "Cleaning SCALE catalog for App: ${chartname}"
    rm -Rf catalog/${train}/${chartname}/${chartversion} 2>/dev/null || :
    rm -Rf catalog/${train}/${chartname}/item.yaml 2>/dev/null || :
}
export -f clean_apps

patch_apps() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    local target="catalog/${train}/${chartname}/${chartversion}"
    echo "Applying SCALE patches for App: ${chartname}"
    sed -i '100,$ d' ${target}/CHANGELOG.md || :
    mv ${target}/app-changelog.md ${target}/CHANGELOG.md 2>/dev/null || :
    # Temporary fix to prevent the UI from bugging out on 21.08
    mv ${target}/values.yaml ${target}/ix_values.yaml 2>/dev/null || :
    touch ${target}/values.yaml
    # mv ${target}/SCALE/ix_values.yaml ${target}/ 2>/dev/null || :
    cp -rf ${target}/SCALE/templates/* ${target}/templates 2>/dev/null || :
    rm -rf ${target}/SCALE 2>/dev/null || :
    touch ${target}/values.yaml
    # Generate item.yaml
    cat ${target}/Chart.yaml | grep "icon" >> catalog/${train}/${chartname}/item.yaml
    sed -i "s|^icon:|icon_url:|g" catalog/${train}/${chartname}/item.yaml
    echo "categories:" >> catalog/${train}/${chartname}/item.yaml
    cat ${target}/Chart.yaml | yq '.annotations."truecharts.org/catagories"' -r >> catalog/${train}/${chartname}/item.yaml
    # Generate SCALE App description file
    cat ${target}/Chart.yaml | yq .description -r >> ${target}/app-readme.md
    echo "" >> ${target}/app-readme.md
    echo "This App is supplied by TrueCharts, for more information please visit https://truecharts.org" >> ${target}/app-readme.md
}
export -f patch_apps

copy_apps() {
    local chart="$1"
    local chartname="$2"
    local train="$3"
    local chartversion="$4"
    echo "Copying App to Catalog: ${2}"
    mkdir -p catalog/${train}/${chartname}/${chartversion}
    cp -Rf ${chart}/* catalog/${train}/${chartname}/${chartversion}/

}
export -f copy_apps

validate_catalog() {
    if [[ -z "$standalone" ]]; then
    echo "Starting Catalog Validation"
    /usr/local/bin/catalog_validate validate --path "${PWD}/catalog"
    fi
}
export -f validate_catalog

upload_catalog() {
    echo "Uploading Catalog..."
    cd catalog
    git config user.name "TrueCharts-Bot"
    git config user.email "bot@truecharts.org"
    git add --all
    git commit -sm "Commit new App releases for TrueCharts" || exit 0
    git push
    cd -
    rm -rf catalog
}
export -f upload_catalog

upload_dhcatalog() {
    echo "Uploading DH-Catalog..."
    cd dh_catalog
    git config user.name "TrueCharts-Bot"
    git config user.email "bot@truecharts.org"
    git add --all
    git commit -sm "Commit new App releases for TrueCharts" || exit 0
    git push
    cd -
    rm -rf dh_catalog
}
export -f upload_dhcatalog



parse_command_line() {
    while :; do
        case "${1:-}" in
            -h|--help)
                show_help
                exit
                ;;
            --config)
                if [[ -n "${2:-}" ]]; then
                    config="$2"
                    shift
                else
                    config=".github/cr.yaml"
                    shift
                fi
                ;;
            -v|--version)
                if [[ -n "${2:-}" ]]; then
                    version="$2"
                    shift
                else
                    echo "ERROR: '-v|--version' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -d|--charts-dir)
                if [[ -n "${2:-}" ]]; then
                    charts_dir="$2"
                    shift
                else
                    echo "ERROR: '-d|--charts-dir' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -u|--charts-repo-url)
                if [[ -n "${2:-}" ]]; then
                    charts_repo_url="$2"
                    shift
                else
                    echo "ERROR: '-u|--charts-repo-url' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -o|--owner)
                if [[ -n "${2:-}" ]]; then
                    owner="$2"
                    shift
                else
                    echo "ERROR: '--owner' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -r|--repo)
                if [[ -n "${2:-}" ]]; then
                    repo="$2"
                    shift
                else
                    echo "ERROR: '--repo' cannot be empty." >&2
                    show_help
                    exit 1
                fi
                ;;
            -p|--production)
                production="true"
                ;;
            -s|--standalone)
                standalone="true"
                ;;
            *)
                break
                ;;
        esac

        shift
    done

    if [[ -z "$owner" ]]; then
        echo "No owner configured, defaulting to truecharts" >&2
        owner="truecharts"
    fi

    if [[ -z "$repo" ]]; then
        echo "No repo configured, defaulting to apps" >&2
        repo="apps"
    fi

    if [[ -z "$charts_repo_url" ]]; then
        charts_repo_url="https://$owner.github.io/$repo"
    fi
}
export -f parse_command_line

lookup_latest_tag() {
    git fetch --tags > /dev/null 2>&1

    if ! git describe --tags --abbrev=0 2> /dev/null; then
        git rev-list --max-parents=0 --first-parent HEAD
    fi
}
export -f lookup_latest_tag

filter_charts() {
    while read -r chart; do
        [[ ! -d "$chart" ]] && continue
        if [[ $(git diff $latest_tag $chart/Chart.yaml | grep "+version") ]]; then
            echo "$chart"
        else
           echo "Version not bumped. Skipping." 1>&2
        fi
    done
}
export -f filter_charts

lookup_changed_charts() {
    local commit="$1"

    local changed_files
    changed_files=$(git diff --find-renames --name-only "$commit" -- "$charts_dir" | grep "Chart.yaml")

    local depth=$(( $(tr "/" "\n" <<< "$charts_dir" | sed '/^\(\.\)*$/d' | wc -l) + 1 ))
    local fields="1-${depth}"

    cut -d '/' -f "$fields" <<< "$changed_files" | uniq | filter_charts
}
export -f lookup_changed_charts

package_chart() {
    local chart="$1"
    local args=("$chart" --package-path .cr-release-packages)
    if [[ -n "$config" ]]; then
        args+=(--config "$config")
    fi

    if [[ -z "$standalone" ]]; then
    echo "Packaging chart '$chart'..."
    cr package "${args[@]}"
    fi
}
export -f package_chart

release_charts() {
    local args=(-o "$owner" -r "$repo" -c "$(git rev-parse HEAD)")
    if [[ -n "$config" ]]; then
        args+=(--config "$config")
    fi

    if [[ -z "$standalone" ]]; then
    echo 'Releasing charts...'
    cr upload "${args[@]}"
    fi
}
export -f release_charts

update_index() {
    local args=(-o "$owner" -r "$repo" -c "$charts_repo_url")
    if [[ -n "$config" ]]; then
        args+=(--config "$config")
    fi

    if [[ -z "$standalone" ]]; then
    echo 'Updating charts repo index...'
    cr index "${args[@]}"
    fi
}
export -f update_index

upload_index() {
  cd .cr-index
  git config user.name "TrueCharts-Bot"
  git config user.email "bot@truecharts.org"
  git add --all
  git commit -sm "Commit released Helm Chart and docs for TrueCharts" || exit 0
  git push
  cd -
  rm -rf .cr-index
}
export -f upload_index

main "$@"
