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
