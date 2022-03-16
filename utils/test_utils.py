import brownie


def jump_to_block(block_height, timestamp=None):
    """
    Jumps to a given block in the future.

    Params:
        block_height     (int): block height to jump to. Should be greater
            or equal to chain's current height. If `block_height` is equal
            to `-1`, jump by one block.
        timestamp   (None|int): timestamp in seconds since Unix epoch. If
            specified, the last mined block will be assigned this timestamp

    Returns chain's new block height.
    """
    start_height = brownie.chain.height
    if block_height != -1:
        assert (
            block_height >= start_height
        ), "block_height should be greater or equal to chain's current block height."
        mine_n_blocks = block_height - start_height
    elif block_height == -1:
        mine_n_blocks = 1
    else:
        raise ValueError(f"Invalid block_height input: {block_height}.")
    return brownie.chain.mine(mine_n_blocks, timestamp)


def mine_at(timestamp, block_height=-1):
    """
    Mines one block with timestamp as defined by `timestamp`.

    Params:
        timestamp       (int): timestamp in seconds since Unix epoch.
        block_height    (int): block height to jump to. By default one block
            will be mined (`-1`). If different from the special value `-1`,
            should be greater or equal to chain's current height.

    Returns chain's new block height.
    """
    return jump_to_block(block_height, timestamp)


def listify(t):
    return list(map(listify, t)) if isinstance(t, (list, tuple)) else t


def setify(t):
    return set(map(listify, t)) if isinstance(t, (list, tuple)) else t


def tuplify(t):
    return tuple(map(tuplify, t)) if isinstance(t, (list, tuple)) else t


def brownie_tuple_to_native(seq):
    seq = listify(seq)
    if isinstance(seq, (tuple, list)):
        for i, s in enumerate(seq):
            seq[i] = brownie_tuple_to_native(s)
        return tuplify(seq)
    else:
        if hasattr(seq, "real"):
            seq = seq.real
        return seq