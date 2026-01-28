# Set default shell with strict flags
set shell := ["bash", "-euo", "pipefail", "-c"]

CURR_VERSION := `cat version.txt`
COMPONENT := "spark-sas7bdat"

default:
    just --list

# Print the current version
print-version:
    @echo "{{CURR_VERSION}}"

# Clean build artifacts
clean:
    @echo "*** Cleaning build artifacts ***"
    sbt clean
    rm -rf target
    rm -rf project/target
    rm -rf project/project/target

# Build package JARs for all Scala versions
build:
    @echo "*** Building packages for all Scala versions ***"
    sbt +package

# Build assembly JARs for all Scala versions (optional, for local use)
build-assembly:
    @echo "*** Building assembly JARs for all Scala versions ***"
    sbt +assembly

# Check if version exists in Nexus for a specific Scala version
check-exists-in-nexus version scala_version:
    @count=$(curl -s --netrc -X GET 'https://nexus.eng.aetion.com/service/rest/v1/search?name={{COMPONENT}}_{{scala_version}}' | jq --arg ver "{{version}}" '[.items[] | select(.version == $ver)] | length'); \
    test $count -eq 0 && echo "false" || echo "true";

# Check if current version exists in Nexus for all Scala versions
check-all-versions:
    @echo "*** Checking version {{CURR_VERSION}} in Nexus for all Scala versions ***"
    @for scala_ver in 2.11 2.12 2.13; do \
        exists=$(just check-exists-in-nexus {{CURR_VERSION}} $scala_ver); \
        echo "Scala $scala_ver: exists=$exists"; \
    done

# Publish to Nexus (cross-compile all Scala versions)
publish:
    @echo "*** Publishing version {{CURR_VERSION}} to Nexus ***"
    sbt +publish

# Set version
set-version version:
    @echo "{{version}}" > version.txt
    @echo "*** Version set to {{version}} ***"

# Bump to next SNAPSHOT version (increment patch)
bump-snapshot:
    @current=$(cat version.txt | sed 's/-SNAPSHOT//'); \
    major=$(echo $current | cut -d. -f1); \
    minor=$(echo $current | cut -d. -f2); \
    patch=$(echo $current | cut -d. -f3); \
    next_patch=$$((patch + 1)); \
    echo "$major.$minor.$next_patch-SNAPSHOT" > version.txt; \
    echo "*** Bumped to $major.$minor.$next_patch-SNAPSHOT ***"

# Remove SNAPSHOT suffix for release
remove-snapshot:
    @current=$(cat version.txt | sed 's/-SNAPSHOT//'); \
    echo "$current" > version.txt; \
    echo "*** Version set to $current (release) ***"

# Generate git version file (for assembly JARs)
generate-git-version:
    @git describe --always > GIT_VERSION
    @echo "*** Generated GIT_VERSION: $(cat GIT_VERSION) ***"

# Run tests
test:
    @echo "*** Running tests ***"
    sbt +test

# Run tests for specific Scala version
test-scala scala_version:
    @echo "*** Running tests for Scala {{scala_version}} ***"
    sbt ++{{scala_version}} test

# Build and test, then publish to Nexus
build-and-publish: clean test
    @echo "*** Tests passed. Publishing to Nexus... ***"
    just publish
