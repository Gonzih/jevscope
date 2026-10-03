# Answer-validation rules — live probe, 2026-10-02

SPEC §5.2 specifies hard validation of every Choice answer. These rules were
probed against the live API (6 responses, 4–6 options each):

| state | choice | argmax | prob sum | confidence |
|---|---|---|---|---|
| the login button is focused and blue | login | login | 1.000 | 1.00 |
| an error dialog says disk full | none | none | 1.000 | 0.92 |
| nothing relevant is on screen | none | none | 1.000 | 1.00 |
| three items match the filter | none | none | 1.000 | **0.41** |
| the user asked to quit without saving | discard | discard | 1.000 | 0.99 |
| completely ambiguous nonsense input zxqw | none | none | 1.000 | 0.99 |

Results: **0** cases where `choice != argmax(probabilities)`, **0** exact ties,
**0** cases where the probability sum drifted more than 0.02 from 1.

So the API is well-behaved on these inputs, and the §5.2 rules are a
**belt-and-braces** check rather than a routine code path. They stay, because
the contract is what the implementation may rely on, not what one sample
happened to do.

## Calibration note

`"three items match the filter"` returns `none` at **confidence 0.41** — a
genuinely ambiguous state where the model correctly declines to name a target
but is far from sure. Under the §5.3 gate (`confidence >= 0.85`) this is
`refused(lowConfidence)`, which is the intended fail-closed behaviour: the model
saying "none" at 0.41 must not be read as confident refusal-to-act.

This is the case that justifies the `lowConfidence` path being distinct from
`Decision(action: .none)`: the first is "we do not know", the second is "we know
there is nothing to do".
