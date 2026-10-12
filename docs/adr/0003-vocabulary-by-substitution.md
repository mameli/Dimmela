# The Vocabulary corrects by deterministic substitution, not by engine biasing

Vocabulary terms are enforced by replacing known variants in the Transcript after recognition, the way Takku does it. The speech engine gets no vocabulary.

Decode-time biasing was rejected on evidence from Takku (Takku ADR 0005): FluidAudio's CTC vocabulary boosting for Parakeet v3 loads an English-only model and, on real Italian speech, turned correct words into Vocabulary terms; FluidAudio's decode-time biasing does not exist for the TDT v3 model. Errors outside the known variants stay in the Transcript; when a Mode is applied, the Post-processing request also carries the Vocabulary terms so the LLM can repair them.
