# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import random

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    # dut.ui_in.value = 0
    # dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    await test_mult(dut, 10, 10)

    # await test_mult_random(dut, 1000, 12)

    await ClockCycles(dut.clk, 10)

async def test_mult_random(dut, count, bit_width=12):
    for _ in range(count):
        x = random.randint(0, 1<<bit_width-1)
        y = random.randint(0, 1<<bit_width-1)
        await test_mult(dut, x, y)

async def test_mult(dut, x, y):
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
