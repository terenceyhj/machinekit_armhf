#!/bin/bash -ex
cd "$(dirname $0)/.."

TRAVIS_PATH=${MACHINEKIT_PATH}/${TRAVIS_DIR}
DOCKER_IMAGE=${DOCKER_IMAGE:-"kinsamanka/mkdocker"}
COMMITTER_NAME="$(git log -1 --pretty=format:%an)"
COMMITTER_EMAIL="$(git log -1 --pretty=format:%ae)"
COMMIT_TIMESTAMP="$(git log -1 --pretty=format:%at)"
DISTRO=${TAG%-*}
MARCH=${TAG#*-}
test ${TRAVIS_PULL_REQUEST} = false && IS_PR=false || IS_PR=true
# Verbose RIP build output:  "true" or "false"
MK_BUILD_VERBOSE=${MK_BUILD_VERBOSE:-"false"}
# Verbose package build output:  "true" or "false"
MK_PACKAGE_VERBOSE=${MK_PACKAGE_VERBOSE:-"false"}
# Verbose regression test debug output:  "true" or "false"
MK_DEBUG_TESTS=${MK_DEBUG_TESTS:-"false"}

cmd=${CMD}
if [ ${CMD} == "run_tests" ];
then
    cmd=build_rip
fi

# run build step
docker run \
    -v $(pwd):${CHROOT_PATH}${MACHINEKIT_PATH} \
    -e FLAV=${FLAV} \
    -e JOBS=${JOBS} \
    -e TAG=${TAG} \
    -e DISTRO=${DISTRO} \
    -e MARCH=${MARCH} \
    -e CHROOT_PATH=${CHROOT_PATH} \
    -e MACHINEKIT_PATH=${MACHINEKIT_PATH} \
    -e TRAVIS_PATH=${TRAVIS_PATH} \
    -e COMMITTER_NAME="${COMMITTER_NAME}" \
    -e COMMITTER_EMAIL="${COMMITTER_EMAIL}" \
    -e COMMIT_TIMESTAMP=${COMMIT_TIMESTAMP} \
    -e MK_BUILD_VERBOSE="${MK_BUILD_VERBOSE}" \
    -e MK_PACKAGE_VERBOSE="${MK_PACKAGE_VERBOSE}" \
    -e IS_PR="${IS_PR}" \
    -e MAJOR_MINOR_VERSION \
    -e PKGSOURCE \
    -e DISTRO \
    -e DEBIAN_SUITE \
    -e GITHUB_URL \
    -e TRAVIS_REPO_SLUG \
    -e TRAVIS_PULL_REQUEST \
    -e TRAVIS_COMMIT \
    -e TRAVIS_BRANCH \
    -e LC_ALL="POSIX" \
    ${DOCKER_IMAGE}:${TAG} \
    ${CHROOT_PATH}${TRAVIS_PATH}/${cmd}.sh

if ${IS_PR}; then
    if test ${cmd} = build_rip; then
	# PR:  Run regression tests
	#
	# tests are run under a new container instead of chrooting
	# this will allow us to run docker without using privileged mode

	# create container using RIP rootfs
	docker build -t mk_runtest .travis/mk_runtests

	# run regressions
	docker run \
	    -e MACHINEKIT_PATH=${MACHINEKIT_PATH} \
	    -e MK_DEBUG_TESTS=${MK_DEBUG_TESTS} \
	    -e LC_ALL="POSIX" \
	    --rm=true mk_runtest /run_tests.sh
    fi
else
    if test ${cmd} != build_rip; then
	# Merge:  Upload packages to packagecloud, if applicable
	if test -n "${PACKAGECLOUD_USER}"; then
	    PACKAGECLOUD_REPO=${PACKAGECLOUD_REPO:-machinekit}
	    repo=${PACKAGECLOUD_USER}/${PACKAGECLOUD_REPO}/debian/${DISTRO}
	    package_cloud push ${repo} ${TRAVIS_BUILD_DIR}/deploy/*deb
	    if test ${MARCH} = 64; then
		package_cloud push ${repo} ${TRAVIS_BUILD_DIR}/deploy/*dsc
	    fi
	fi	
    fi
fi
