"""Finite checks of chapter 10's teaching models, separate from LLVM solvers."""
import itertools
import json
import math
import random


def hopfield():
    states = list(itertools.product((-1, 1), repeat=3))
    traces = flips = non_global = 0
    for parameters in itertools.product((-1, 0, 1), repeat=6):
        weights = ((0, parameters[0], parameters[1]),
                   (parameters[0], 0, parameters[2]),
                   (parameters[1], parameters[2], 0))
        bias = parameters[3:]

        def energy(state):
            # Count each undirected edge once, independently of the local update.
            return -sum(weights[i][j] * state[i] * state[j]
                        for i in range(3) for j in range(i + 1, 3)) - sum(
                            bias[i] * state[i] for i in range(3))

        optimum = min(map(energy, states))
        for initial in states:
            state = list(initial)
            seen = {tuple(state)}
            while True:
                changed = False
                for i in range(3):
                    old = state[i]
                    field = bias[i] + sum(weights[i][j] * state[j] for j in range(3))
                    new = 1 if field > 0 else -1 if field < 0 else old
                    before = energy(state)
                    state[i] = new
                    delta = energy(state) - before
                    assert delta == -(new - old) * field
                    if new != old:
                        assert delta < 0 and tuple(state) not in seen
                        seen.add(tuple(state))
                        flips += 1
                        changed = True
                if not changed:
                    break
                assert len(seen) <= len(states)
            # A complete unchanged round is stable under every single-node flip.
            for i in range(3):
                neighbor = state.copy()
                neighbor[i] *= -1
                assert energy(neighbor) >= energy(state)
            non_global += energy(state) > optimum
            traces += 1
    assert non_global > 0
    # Synchronous updates violate the single-node premise: even a symmetric
    # two-node network can oscillate. Zero bias, w01 = w10 = 1.
    synchronous = [(1, -1)]
    for _ in range(2):
        a, b = synchronous[-1]
        synchronous.append((b, a))
    assert synchronous[0] == synchronous[2] != synchronous[1]
    return {"networks": 3 ** 6, "initial_state_traces": traces,
            "strictly_decreasing_flips": flips,
            "stable_but_not_global_minimum_traces": non_global,
            "synchronous_cycle": synchronous,
            "scope": "Three-node, symmetric, zero-diagonal binary model; cyclic asynchronous updates with ties unchanged. Not LLVM SpillPlacement's three-state implementation or a general proof."}


def pbqp():
    c0, c1, edge = [2, 0], [2, 4], [[2, 1], [1, 4]]
    book_r1 = [c1[b] + min(c0[a] + edge[a][b] for a in range(2)) for b in range(2)]
    assert book_r1 == [3, 7]
    unary, left, right = [1, 3], [[2, 2], [1, 4]], [[2, 1], [1, 4]]
    book_r2 = [[min(unary[b] + left[a][b] + right[b][c] for b in range(2))
                for c in range(2)] for a in range(2)]
    assert book_r2 == [[5, 4], [4, 3]]

    random_source = random.Random(1818)
    costs = [-3, 0, 1, 5, math.inf]
    dimensions = set()
    feasible = 0
    for _ in range(512):
        sizes = [random_source.randint(1, 4) for _ in range(3)]
        dimensions.add(tuple(sizes))
        unary = [[random_source.choice(costs) for _ in range(n)] for n in sizes]
        c0, c1, c2 = unary
        edges = {(i, j): [[random_source.choice(costs) for _ in range(sizes[j])]
                          for _ in range(sizes[i])]
                 for i, j in ((0, 1), (1, 2), (0, 2))}
        e01, e12, e02 = (edges[key] for key in ((0, 1), (1, 2), (0, 2)))
        assignments = list(itertools.product(*(range(n) for n in sizes)))

        def objective(assignment, pairs):
            return sum(unary[i][a] for i, a in enumerate(assignment)) + sum(
                edges[i, j][assignment[i]][assignment[j]] for i, j in pairs)

        # R1: eliminate node 0 in the path 0--1--2, then recover its choice.
        r1 = [c1[b] + min(c0[a] + e01[a][b] for a in range(sizes[0]))
              for b in range(sizes[1])]
        b, c = min(itertools.product(range(sizes[1]), range(sizes[2])),
                   key=lambda bc: r1[bc[0]] + c2[bc[1]] + e12[bc[0]][bc[1]])
        a = min(range(sizes[0]), key=lambda a: c0[a] + e01[a][b])
        original_min = min(objective(choice, ((0, 1), (1, 2))) for choice in assignments)
        assert r1[b] + c2[c] + e12[b][c] == original_min
        assert objective((a, b, c), ((0, 1), (1, 2))) == original_min

        # R2: eliminate node 1 in a triangle. The existing edge must be added.
        r2 = [[e02[a][c] + min(c1[b] + e01[a][b] + e12[b][c]
                                for b in range(sizes[1]))
               for c in range(sizes[2])] for a in range(sizes[0])]
        a, c = min(itertools.product(range(sizes[0]), range(sizes[2])),
                   key=lambda ac: c0[ac[0]] + c2[ac[1]] + r2[ac[0]][ac[1]])
        b = min(range(sizes[1]), key=lambda b: c1[b] + e01[a][b] + e12[b][c])
        original_min = min(objective(choice, ((0, 1), (1, 2), (0, 2))) for choice in assignments)
        assert c0[a] + c2[c] + r2[a][c] == original_min
        assert objective((a, b, c), ((0, 1), (1, 2), (0, 2))) == original_min
        feasible += math.isfinite(original_min)
    return {"book_r1": book_r1, "book_r2": book_r2, "seed": 1818,
            "sampled_three_node_instances": 512, "distinct_option_count_triples": len(dimensions),
            "feasible_triangles": feasible, "all_infinite_triangles": 512 - feasible,
            "scope": "One R1 or R2 reduction per sampled instance, checked against all assignments, with conditional traceback, rectangular matrices, negative costs, infinity, and existing 0--2 edges. An all-infinite optimum preserves infeasibility, not a finite feasible assignment. No multistep reduction stack, high-degree heuristic, arbitrary stored-edge transpose adapter, or claim of LLVM-wide optimality."}


def run_models():
    return {"hopfield": hopfield(), "pbqp": pbqp()}


if __name__ == '__main__':
    print(json.dumps(run_models(), ensure_ascii=False, indent=2))
