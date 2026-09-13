"""Bounded bit-vector checks for the explanatory examples, not LLVM semantics."""
def run_models():
    mask = (1 << 16) - 1
    values = [0, 0x7fff, 0x8000, 0xffff, 0x12348000, 0xffff1234]
    for wide in values:
        small = wide & mask
        assert (wide & mask) == small
        zero_extended = small
        sign_extended = (small if small < 0x8000 else small - 0x10000) & 0xffffffff
        if wide == 0x12348000:
            assert zero_extended != wide and sign_extended != wide
    frequency = 1
    gpr_cost = frequency * 1
    fpr_cost = frequency * (1 + 2 * 4 + 5)
    assert (gpr_cost, fpr_cost) == (1, 14)
    return {'anyext_low_bits_checked_values':len(values),'assumed_bank_costs':{'gpr':gpr_cost,'fpr':fpr_cost},'scope':'bit-vector examples; not full poison/undef semantics or RegBankSelect cost search'}
if __name__ == '__main__':
    import json
    print(json.dumps(run_models()))
