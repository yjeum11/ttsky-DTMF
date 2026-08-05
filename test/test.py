# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import random
import wave
import numpy as np
from dtmf_goertzel import all_goertzel_sprevs, goertzel_power_fixed, goertzel_sprevs, all_powers, get_max_rowcol
from synth import synthesize

@cocotb.test()
async def test_toplevel(dut):
    dut._log.info("TopLevel test")
    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await reset_dut(dut)

    samples = []

    # with wave.open("./one.wav", 'rb') as wavfile:
    # n_frames = wavfile.getnframes()
    # b = wavfile.readframes(n_frames)

    await superblock(dut, 512, '#')
    # await superblock(dut, 512, '1')
    # await superblock(dut, 512, '2')

    # await block(dut, samples[0:512], 512)
    # await block(dut, samples[512:1024], 512, is_col=True)

async def get_result(dut):
    while dut.uio_out.value[2] != 1:
        await RisingEdge(dut.clk)
    return dut.uo_out.value

async def superblock(dut, block_size, key='1'):
    samples = np.frombuffer(synthesize([key]), dtype=np.uint8).astype(np.float64) - 128

    assert len(samples) >= block_size

    result_task = cocotb.start_soon(get_result(dut))

    await block(dut, samples[0:block_size], block_size)
    await block(dut, samples[block_size:2*block_size], block_size, is_col=True)

    outval = await result_task

    sim_row_idx = outval[7:4].to_unsigned()
    sim_col_idx = outval[3:0].to_unsigned()

    golden_row_idx, golden_col_idx = get_max_rowcol(samples, 44100)

    print(f"sim row: {sim_row_idx}")
    print(f"sim col: {sim_col_idx}")

    assert sim_row_idx == golden_row_idx
    assert sim_col_idx == golden_col_idx


async def block(dut, samples, block_size, is_col=False):
    assert len(samples) == block_size
    # power_task = cocotb.start_soon(get_power_values(dut, num_powers))
    # s_prev_task = cocotb.start_soon(get_sprev_values(dut, block_size, 4 if is_col else 0))

    for i, s in enumerate(samples):
        if i % 10 == 0:
            print(f"{i} samples")
        s = int(s)
        while dut.uio_out.value[0] != 1:
            await RisingEdge(dut.clk)
        await ClockCycles(dut.clk, 3)
        dut.uio_in.value = 2
        dut.ui_in.value = s
        await RisingEdge(dut.clk)
        dut.uio_in.value = 0
        await RisingEdge(dut.clk)

    while dut.uio_out.value[0] != 1:
        await RisingEdge(dut.clk)

    # print("done with samples")
    # sim_powers = await power_task
    # print("power task")
    # sim_s_prev = await s_prev_task
    # print("s_prev_task")

    # golden_s_prev = None
    # if not is_col:
        # golden_s_prev = goertzel_sprevs(samples, 44100, 697)
    # else:
        # golden_s_prev = goertzel_sprevs(samples, 44100, 1209)
    # print(f"golden s_prev: {golden_s_prev}")
    # print(f"sim s_prev: {sim_s_prev}")
    
    # for i, (x, y) in enumerate(zip(golden_s_prev, sim_s_prev[1:])):
    #     if x != y:
    #         print(f"wrong at idx {i}, gold={x}, sim={y}")
    #         break

    # golden_powers = all_powers(samples)

    # print(f"golden powers: {golden_powers}")
    # print(f"sim powers: {sim_powers}")
    # print(f"max_row: {dut.user_project.max_row_idx.value}, max_col: {dut.user_project.max_col_idx.value}")

    # assert golden_powers == sim_powers

async def get_power_values(dut, num_powers):
    res = []
    for _ in range(num_powers):
        while dut.user_project.power_valid.value != 1:
            await RisingEdge(dut.clk)
        res.append(dut.user_project.power.value.to_signed())
        await RisingEdge(dut.clk)
    return res

async def get_sprev_values(dut, block_size, target_idx):
    res = []
    for _ in range(block_size):
        while dut.user_project.s_prev_write.value != 1 or dut.user_project.coeff_idx.value != target_idx:
            await RisingEdge(dut.clk)
        # print(f"s_prev_idx: {dut.user_project.s_prev_idx.value.to_signed()}")
        # print(f"s_prev_write: {dut.user_project.s_prev_write.value}")
        # print(f"simtime: {cocotb.utils.get_sim_time()}")
        res.append(dut.user_project.s_prev.value.to_signed())
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    return res

# @cocotb.test()
async def test_mult(dut):
    dut._log.info("Random Mult Test")
    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    await mult_random(dut, 1000, 16, 8)
    # await mult(dut, 15, 121)

# @cocotb.test()
# async def test_iir(dut):
#     # Set the clock period to 10 us (100 KHz)
#     clock = Clock(dut.clk, 10, unit="us")
#     cocotb.start_soon(clock.start())
#     dut.sample.value = 0
#     dut.sample_valid.value = 0
#     await reset_dut(dut)
#     await iir(dut)

# @cocotb.test()
async def test_power(dut):
    block_size = dut.my_power.BLOCK_SIZE.value.to_unsigned()
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.sample.value = 0
    dut.sample_valid.value = 0
    await reset_dut(dut)
    samples = []
    with wave.open("./dtmf.wav", 'rb') as wavfile:
        n_frames = wavfile.getnframes()
        b = wavfile.readframes(n_frames)
        samples = np.frombuffer(b, dtype=np.uint8).astype(np.float64) - 128.0
    samples = samples[100000:100000+512]

    dut.start.value = 1;
    s_prevs = []
    print("testing power")

    for s in samples:
        s = int(s)
        while dut.sample_ready.value != 1:
            await RisingEdge(dut.clk)
        dut.sample_valid.value = 1
        dut.sample.value = s
        await RisingEdge(dut.clk)
        dut.sample_valid.value = 0
        await RisingEdge(dut.clk)
        s_prevs.append(dut.my_power.s_prev.value.to_signed())

    golden = goertzel_power_fixed(samples, 41000, 697)

    await RisingEdge(dut.power_valid)

    # print(f"dut.s_prevs = {s_prevs}")
    print(f"dut.power = {dut.power.value.to_signed()}")
    print(f"golden power = {golden}")

    assert dut.power.value.to_signed() == golden

async def reset_dut(dut):
    # Reset
    dut._log.info("Reset")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

async def mult_random(dut, count, bit_width_a=12, bit_width_b=12):
    for _ in range(count):
        x = random.randint(-(1 << (bit_width_a-1)), (1 << (bit_width_a-1)) -1)
        y = random.randint(-(1 << (bit_width_b-1)), (1 << (bit_width_b-1)) -1)
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
    samples = []
    with wave.open("./dtmf.wav", 'rb') as wavfile:
        n_frames = wavfile.getnframes()
        b = wavfile.readframes(64)
        samples = np.frombuffer(b, dtype=np.uint8).astype(np.float64) - 128.0

    s_prev = []
    for s in samples:
        s = int(s)
        while dut.sample_ready.value != 1:
            await RisingEdge(dut.clk)
        dut.sample_valid.value = 1
        dut.sample.value = s
        await RisingEdge(dut.clk)
        dut.sample_valid.value = 0
        await RisingEdge(dut.valid)
        curr_s_prev = []
        for i in range(7):
            curr_s_prev.append(dut.s_prev.value[(i+1)*24-1:i*24].to_signed())
        s_prev.append(curr_s_prev)

    golden = all_goertzel_sprevs(samples, 44100.0)

    # print(s_prev)
    # print(golden)

    assert s_prev == golden

