# Harbor Artifact Workflow

This document describes the generic artifact workflow supported by Harbor
Visible Kit. It intentionally uses example hostnames, projects, repositories,
and versions so it can be shared publicly.

## Supported Artifacts

Harbor Visible Kit focuses on desktop workflows for teams that publish and
retrieve artifacts through a Harbor registry.

- JAR service packages can be wrapped into a minimal image-style artifact and
  later extracted back to the original JAR file.
- Docker image archives can be imported, tagged, and pushed to a selected
  Harbor project.
- Teams can browse Harbor projects, repositories, and tags before pulling or
  exporting selected artifacts.

## Example Naming

Use documentation-only values when adapting these examples:

- Registry: `harbor.example.test:8080`
- Project: `release`
- JAR repository: `example-service-artifacts`
- Image repository: `example-service`
- Version: `1.2.3`

Example target references:

```text
harbor.example.test:8080/release/example-service-artifacts:1.2.3-jar
harbor.example.test:8080/release/example-service:1.2.3
```

## JAR Package Flow

1. Select one or more `.jar` files.
2. Choose a Harbor project and version tag.
3. Review the resolved target repository and tag.
4. Push the generated artifact to Harbor.
5. Pull the artifact later and extract the original JAR to a local folder.

## Docker Image Archive Flow

1. Select one or more `.tar`, `.tar.gz`, or `.tgz` image archives.
2. Choose a Harbor project and version tag.
3. Review the resolved image target before publishing.
4. Import, retag, and push each archive in sequence.

## Local Docker Requirements

The app shells out to Docker for import, push, pull, save, and extraction
operations. Users must install Docker CLI and make sure their local Docker
engine can reach the target Harbor registry.

For HTTP registries or custom ports, configure Docker according to your
organization's registry policy before using this app.
