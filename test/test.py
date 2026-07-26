# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import random
import wave
from dtmf_goertzel import goertzel_sprevs

# @cocotb.test()
# async def test_mult(dut):
#     dut._log.info("Random Mult Test")
#     # Set the clock period to 10 us (100 KHz)
#     clock = Clock(dut.clk, 10, unit="us")
#     cocotb.start_soon(clock.start())
#     await reset_dut(dut)
#     await mult_random(dut, 1000, 8)
#     await mult(dut, 15, 121)

# @cocotb.test()
# async def test_iir(dut):
#     # Set the clock period to 10 us (100 KHz)
#     clock = Clock(dut.clk, 10, unit="us")
#     cocotb.start_soon(clock.start())
#     dut.sample.value = 0
#     dut.sample_valid.value = 0
#     dut.coeff.value = 0
#     await reset_dut(dut)
#     await iir(dut)

@cocotb.test()
async def test_power(dut):
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.sample.value = 0
    dut.sample_valid.value = 0
    await reset_dut(dut)
    samples = []
    with wave.open("./test_dtmf.wav", 'rb') as wavfile:
        b = wavfile.readframes(16)
        samples = [x - 128 for x in list(b)]

    dut.start.value = 1;

    for s in samples:
        if dut.sample_ready.value != 1:
            await RisingEdge(dut.sample_ready)
        dut.sample_valid.value = 1
        dut.sample.value = s
        await ClockCycles(dut.clk, 1)
        dut.sample_valid.value = 0


        




async def reset_dut(dut):
    # Reset
    dut._log.info("Reset")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

async def mult_random(dut, count, bit_width=12):
    for _ in range(count):
        x = random.randint(-(1 << (bit_width-1)), (1 << (bit_width-1)) -1)
        y = random.randint(-(1 << (bit_width-1)), (1 << (bit_width-1)) -1)
        await mult(dut, x, y)

async def mult(dut, x, y):
    dut.A.value = x
    dut.B.value = y
    if dut.AB_ready.value != 1:
        await RisingEdge(dut.AB_ready)
    dut.AB_valid.value = 1
    await ClockCycles(dut.clk, 1)
    dut.AB_valid.value = 0
    await RisingEdge(dut.Q_valid)
    dut.AB_valid.value = 0
    print(f"{dut.A.value.to_signed()} * {dut.B.value.to_signed()} is {dut.Q.value.to_signed()}")
    assert dut.Q.value.to_signed() == x * y
    await ClockCycles(dut.clk, 1)

async def iir(dut):
    coeff = 1019 # coeff for row 1
    samples = []
    with wave.open("./test_dtmf.wav", 'rb') as wavfile:
        n_frames = wavfile.getnframes()
        b = wavfile.readframes(4)
        samples = [x - 128 for x in list(b)]

    dut.coeff.value = coeff

    s_prev = []
    for s in samples:
        dut.sample.value = s
        if dut.sample_ready.value != 1:
            await RisingEdge(dut.sample_ready)
        dut.sample_valid.value = 1
        await RisingEdge(dut.valid)
        await ClockCycles(dut.clk, 1)
        s_prev.append(dut.s_prev.value.to_signed())

    golden = goertzel_sprevs(samples, 44100, 697)

    assert s_prev == golden

