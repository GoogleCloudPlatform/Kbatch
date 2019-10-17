// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"log"
	"os"
)

var in = flag.String("in", "", "Input PNG image file.")
var out = flag.String("out", "", "Output PNG image file.")

type settable interface {
	Set(x, y int, c color.Color)
}

func main() {
	flag.Parse()

	reader, err := os.Open(*in)
	if err != nil {
		log.Fatal(err)
	}
	defer reader.Close()

	i, _, err := image.Decode(reader)
	if err != nil {
		log.Fatal(err)
	}
	ci, ok := i.(settable)
	if !ok {
		log.Fatal(fmt.Errorf("image format is not settable"))
	}

	// To create a greyscale image, set all color components of each pixel to the max of the components.
	bounds := i.Bounds()
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, a := i.At(x, y).RGBA()
			var max uint32
			if r > g {
				if r > b {
					max = r
				} else {
					max = b
				}
			} else {
				if g > b {
					max = g
				} else {
					max = b
				}
			}
			ci.Set(x, y, color.RGBA{R: uint8(max), G: uint8(max), B: uint8(max), A: uint8(a)})
		}
	}

	writer, err := os.Create(*out)
	if err != nil {
		log.Fatal(err)
	}
	defer writer.Close()

	err = png.Encode(writer, i)
	if err != nil {
		log.Fatal(err)
	}
}
