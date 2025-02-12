// +build ignore

package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"log"
)

func hasErrCode(idx int) bool {
	return idx == 8 || (idx >= 10 && idx <= 14) || idx == 17
}

func genasm() {
	buf := new(bytes.Buffer)
	buf.WriteString("// Code generated by genvector.go using 'go generate'. DO NOT EDIT.\n")
	buf.WriteString(`#include "textflag.h"`)
	buf.WriteString("\n\n")
	for i := 0; i < 256; i++ {
		fmt.Fprintf(buf, "TEXT ·trap%d(SB), NOSPLIT, $0-0\n", i)
		if !hasErrCode(i) {
			buf.WriteString("  PUSHQ    $0\n")
		}
		fmt.Fprintf(buf, "  PUSHQ    $%d\n", i)
		buf.WriteString("  JMP    alltraps(SB)\n")
		buf.WriteString("  POPQ    AX\n")
		if !hasErrCode(i) {
			buf.WriteString("  POPQ    AX\n")
		}
		buf.WriteString("  RET\n\n")
	}
	err := ioutil.WriteFile("vectors.s", buf.Bytes(), 0644)
	if err != nil {
		log.Fatal(err)
	}
}

func gengo() {
	buf := new(bytes.Buffer)
	buf.WriteString("// Code generated by genvector.go using 'go generate'. DO NOT EDIT.\n")
	buf.WriteString("package kernel\n\n")
	for i := 0; i < 256; i++ {
		fmt.Fprintf(buf, "//go:nosplit\n")
		fmt.Fprintf(buf, "func trap%d()\n", i)
	}
	buf.WriteString("\n")

	buf.WriteString("var vectors = [...]func(){\n")
	for i := 0; i < 256; i++ {
		fmt.Fprintf(buf, "trap%d,\n", i)
	}
	buf.WriteString("}\n\n")

	err := ioutil.WriteFile("vectors.go", buf.Bytes(), 0644)
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	genasm()
	gengo()
}
