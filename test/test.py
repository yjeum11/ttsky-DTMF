# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import random
import wave

# @cocotb.test()
# async def test_mult(dut):
#     dut._log.info("Random Mult Test")

    # # Set the clock period to 10 us (100 KHz)
    # clock = Clock(dut.clk, 10, unit="us")
    # cocotb.start_soon(clock.start())
    # await reset_dut(dut)
    # await mult_random(dut, 100, 8)

@cocotb.test()
async def test_iir(dut):
    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.sample.value = 0
    dut.sample_valid.value = 0
    dut.coeff.value = 0
    await reset_dut(dut)
    await iir(dut)

async def reset_dut(dut):
    # Reset
    dut._log.info("Reset")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

async def mult_random(dut, count, bit_width=12):
    for _ in range(count):
        x = random.randint(0, (1<<bit_width)-1)
        y = random.randint(0, (1<<bit_width)-1)
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
    assert dut.Q.value == x * y
    await ClockCycles(dut.clk, 1)

async def iir(dut):
    coeff = 1019 # coeff for row 1
    samples = []
    with wave.open("./test_dtmf.wav", 'rb') as wavfile:
        b = wavfile.readframes(1)
        samples = list(b)

    dut.coeff.value = coeff

    s_prev = []
    s_prev2 = []
    for s in samples:
        dut.sample.value = s
        if dut.sample_ready.value != 1:
            await RisingEdge(dut.sample_ready)
        dut.sample_valid.value = 1
        await RisingEdge(dut.valid)
        await ClockCycles(dut.clk, 1)
        s_prev.append(dut.s_prev.value)
        s_prev2.append(dut.s_prev2.value)

    print(s_prev)
    print(s_prev2)


