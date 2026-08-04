<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Dual-Tone Multi Frequency (DTMF) signaling is a way of signaling between telephone equipment which uses two different  

The circuit works by implementing a discrete Fourier transform (DFT) using the Goertzel algorithm, which is standard for this use case.

The DFT makes it possible for us to determine which of the DTMF frequencies are active in the incoming signal.
Goertzel makes it very simple to calculate DFT terms for a fixed target frequency using only a few multiplications and additions.

## How to test

The chip takes unsigned 8-bit samples centered at 128 through a ready-valid handshake. When the chip signals 

## External hardware


