# Pin Go dependencies

## Motivation

When you develop your `go` project, it is important to pin all dependencies. While you should update your dependencies regularly, this should not happen unintentionally, and all pipeline steps should produce the same result.

## Prerequisites

A Linux or MacOS machine for local development. If you are running Windows, you first need to set up the *Windows Subsystem for Linux (WSL)* environment.

You need `docker cli` and `docker-compose` on your machine for testing purposes, and/or on the machines that run your pipeline.
You can check both of these by running the following commands:
```sh
docker --version
docker-compose --version
```

## Investigation

Let's start by creating a project that has a 3rd party dependency. Put the following into your `main.go`:
```sh
package main

import (
	"fmt"

	"github.com/spf13/cobra"
)

func main() {
	var rootCmd = &cobra.Command{
		Use:   "app",
		Short: "MyApp",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Hallo from MyApp!")
		},
	}

	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
	}
}
```

Generate the `go.mod` file by running:
```sh
go mod init app
```
, or create it manually. You will end up with something like this:
```sh
module pin-go-dependencies

go 1.20
```

To add the project dependencies, you can run:
```sh
go mod tidy
```
`cobra` is the only 3rd party dependency used in the project. This will add the following to the `go.mod` file:
```sh
require github.com/spf13/cobra v1.8.0

require (
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/spf13/pflag v1.0.5 // indirect
)
```
If you take a look at `main.go`, you will notice that there is only one 3rd party dependency. So why are there 2 extra indirect dependencies? They were added because the `cobra` dependency internally uses some other 3rd party dependencies as well.

Note that another file named `go.sum` was also generated. This file contains extra information for the dependencies:
```sh
github.com/cpuguy83/go-md2man/v2 v2.0.3/go.mod h1:tgQtvFlXSQOSOSIRvRPT7W67SCa46tRHOmNcaadrF8o=
github.com/inconshreveable/mousetrap v1.1.0 h1:wN+x4NVGpMsO7ErUn/mUI3vEoE6Jt13X2s0bqwp9tc8=
github.com/inconshreveable/mousetrap v1.1.0/go.mod h1:vpF70FUmC8bwa3OWnCshd2FqLfsEA9PFc4w1p2J65bw=
github.com/russross/blackfriday/v2 v2.1.0/go.mod h1:+Rmxgy9KzJVeS9/2gXHxylqXiyQDYRxCVz55jmeOWTM=
github.com/spf13/cobra v1.8.0 h1:7aJaZx1B85qltLMc546zn58BxxfZdR/W22ej9CFoEf0=
github.com/spf13/cobra v1.8.0/go.mod h1:WXLWApfZ71AjXPya3WOlMsY9yMs7YeiHhFVlvLyhcho=
github.com/spf13/pflag v1.0.5 h1:iy+VFUOCP1a+8yFto/drg2CJ5u0yRoB7fZw3DKv/JXA=
github.com/spf13/pflag v1.0.5/go.mod h1:McXfInJRrz4CZXVZOBLb0bTZqETkiAhM9Iw0y3An2Bg=
gopkg.in/check.v1 v0.0.0-20161208181325-20d25e280405/go.mod h1:Co6ibVJAznAaIkqp8huTwlJQCZ016jof/cbN4VW5Yz0=
gopkg.in/yaml.v3 v3.0.1/go.mod h1:K4uyk7z7BCEPqu6E+C64Yfv1cQ7kz7rIZviUmN+EgEM=
```
Note that most dependencies have 2 entries, one with `h1` and one with `go.mod`. The first one represents the hash of the source code of the dependency, while the second is the hash of the binary.

The correct way to pin the `go` dependencies is to use such `go.mod` and `go.sum` files and add them to your repository.

You probably noticed that both `go.mod` and `go.sum` contain versions of dependencies. You might ask yourself why `go.sum` is needed. It is a good idea to keep `go.sum` in your repository because the hashes provide an extra layer of security for the dependencies.

Let's test this all out. The plan is the following:
1) Recommended way
Since the repository comes with `go.mod` and `go.sum` files, let's use `go build` first to generate the application.
2) Not recommended way
Get rid of the `go.mod` and `go.sum` files and use `go mod init app`, `go mod tidy` and `go build` generate the application.
3) Compare results
In this step we want to generate hashes for the 2 apps and display them to see if they are the same.

## Step 1

Let's write a script to build the application:
```sh
(cd cmd/app && go build)
mv cmd/app/app output/app1
```
The application will be moved to an `output` directory.

We want to use docker containers to do these tests since we might have some newer software versions locally. Let's build the `dockerfile`:
```sh
FROM golang:1.20.5-alpine3.17

ADD . /app
WORKDIR /app

CMD ["sh"]
```

Let's write the docker-compose file for the first step. We want to mount the `output` directory as a volume so that we also have access to it locally and run the script we just wrote:
```sh
services:
  generate1:
    image: nodeimage
    network_mode: host
    working_dir: /app
    volumes:
      - ./output:/app/output
    entrypoint: ["sh", "-c"]
    command: ["sh scripts/generate1.sh"]
```

## Step 2

Let's write a similar script to build the application. The difference is that we will delete the `go.mod` and `go.sum` files and build from scratch:
```sh
rm -f go.mod go.sum
go mod init app
go mod tidy
(cd cmd/app && go build)
mv cmd/app/app output/app2
```

We can reuse the `dockerfile`. For this step, we can just write a second service in the docker-compose file to run the script:
```sh
  generate2:
    image: nodeimage
    network_mode: host
    working_dir: /app
    volumes:
      - ./output:/app/output
    entrypoint: ["sh", "-c"]
    command: ["sh scripts/generate2.sh"]
```

## Step 3

First of all, let's write the script for this step. We want to generate hash files from the 2 outputs and just print them:
```sh
SHA1=$(sha256sum output/app1 | awk '{print $1}')
SHA2=$(sha256sum output/app2 | awk '{print $1}')

echo "Printing the hashes of the generated apps, with and without go.mod, go.sum:"
echo $SHA1
echo $SHA2
```

We can reuse the `dockerfile`. For this step, we can just write a third service in the docker-compose file to run the script:
```sh
  compare:
    image: nodeimage
    network_mode: host
    working_dir: /app
    volumes:
      - ./output:/app/output
    entrypoint: ["sh", "-c"]
    command: ["sh scripts/compare.sh"]
```

Let's add all these steps and add some cleanup as well in `run.sh`:
```sh
# Cleanup
rm -rf output

# Build the Docker image
docker build -t goimage .

# Generate the app generated by using go build
docker-compose run --rm generate1

# Generate the app generated by using go build without so.mod and go.sum
docker-compose run --rm generate2

# Compare the two apps. This will print their respective SHA1 checksums
docker-compose run --rm compare
```

Calling
```sh
sh run.sh
```
will generate 2 different applications from steps 1 and 2 and print their hashes.

You might wonder whether the 2 hashes are different just because of some factors that were not considered. That is a fair question. You can make sure that this is not the case just by running the `run.sh` script a second time. The expectation is to obtain the same hashes as before.

## Takeaways

When working with `go`:
- add `go.mod` and `go.sum` to your repository
- use `go build` when building the product in the pipeline
- to update one or more dependencies you can update the versions in the `go.mod` file and call `go mod tidy` to update the indirect dependencies and the `go.sum` file
- to update one dependency to the latest version you can use `go get -u github.com/spf13/cobra` for example and `go mod tidy` to update the indirect dependencies and the `go.sum` file
