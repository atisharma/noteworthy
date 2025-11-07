# Noteworthy MCP server

Noteworthy consists of knowledge distillation and synthesis RAG functions.
It exposes MCP tools including

- atomize
- synthesize
- recall
- delete
- delete-bad

These are explained below.

It also exposes various web-RAG tools inherited from [trag](https://github.com/atisharma/trag),

- arxiv (summary search and latex retrieval)
- book-search
- ddg-news
- url
- weather
- wikipedia
- wikinews
- youtube

Composed versions of these are available: distil over arxiv latex, youtube transcript, url.


## Distill: knowledge distillation

Normally in RAG we take source documents and chop them up into pieces and store
those pieces. Instead, here we take a source document into the LLM context, and
generate from it into (a series of) pithy notes of a certain length. That
length should fit into the embedding model context. These condensed notes
(containing only the noteworthy material) is then ingested into the vdb.
Each note should be about 150-400 words.

Example output:

```json
[
    {  
        "added": "2025-10-31T10:26:47.795647+00:00",  
        "hash": "1da528db3ff7bbd4f57b072940742947da2040af",  
        "source": "/tmp/What-is-Life.txt",  
        "title": "Information Density of Molecular Structures",  
        "date": null,  
        "idea": "A molecular structure can embody a vast number of complex arrangements within a small space, making it a plausible physical substrate for a complex genetic code.",  
        "details": "To address how a gene's small size can contain a complex developmental code, the text uses a combinatorial analogy to Morse code. It illustrates that a relatively small number of atom types arranged in a well-ordered, non-repetitive fashion can produce an almost unlimited number of unique configurations. This mathematical potential, where even a structure of 25 atomic 'letters' can yield trillions of combinations, supports the plausibility that a gene's molecular structure could precisely encode a highly specified and intricate plan for an organism's development."  
    },  
    {  
        "added": "2025-10-31T10:26:47.532276+00:00",  
        "hash": "bc55725c5f484ae308558895793d7ee999e19e1a",  
        "source": "/tmp/What-is-Life.txt",  
        "title": "The Hereditary Substance as a Molecular Structure",  
        "date": null,  
        "idea": "A gene is theorized to be a large, molecule-like structure capable of discontinuous, isomeric change, with its stability against thermal disturbance dictating the rarity of mutations.",  
        "details": "Proposing a general model based on physicist M. Delbruck's work, the text suggests a gene is a huge molecule that only changes through discontinuous rearrangements of its atoms into an isomeric form. These rare events, identified as spontaneous mutations, are caused by significant energy impacts sufficient to surpass the high energy thresholds separating the gene's stable configuration from possible alternatives. The stability and permanence of the hereditary substance depend on these thresholds being high enough to withstand the average energy from thermal motion."  
    }
]
```


## Recall

Recall is exposed as an MCP tool. The top *n* results are returned.
The recall can be from facts and/or insights vdb.

**TODO** Use reranker for relevant knowledge atoms.


## Synthesise: Knowledge synthesis from knowledge atoms

We move from librarian to active reader.

These note may contain references,
including the source material, but these should be validated. This is like an
auto-zettelkasten.

```json
{
  "date": "[ISO 8601 datetime string]",
  "timestamp": int,
  "theme": "[string]",
  "understanding": "[string]",
  "sources": "[array of strings]",
  "analysis": "[string]",
  "questions": "[string]"
}
```

For instance,

```json
{
  "timestamp": "2025-10-26T20:45:00Z",
  "theme": "Human-AI Collaborative Knowledge Synthesis",
  "understanding": "A two-tier RAG note-taking pipeline—machine-distilled atomic facts followed by human-curated synthesis entries—can be kept epistemically clean by inserting a ‘novelty referee’ prompt between the tiers; this referee rejects algorithmic platitudes and thereby prevents the knowledge base from drowning in its own low-entropy slop.",
  "sources": [
    "Assistant's knowledge-distillation prompt (2025-10-26)",
    "Assistant's intellectual-synthesis prompt (2025-10-26)",
    "User’s novelty-filter prompt specification (2025-10-26)"
  ],
  "analysis": "The referee itself is still an LLM, so its judgments risk regress: if the judge is lenient, the slop still leaks in; if too strict, genuine but non-obvious links may be vetoed. A human final review remains indispensable.",
  "questions": "Prototype the referee prompt as a GitHub Action that auto-labels synthesis notes ‘RECORD’ or ‘REJECT’; measure false-positive and false-negative rates against a labelled set; iterate prompt until precision ≥ 0.9."
}
```


## Referee

Most ideas are not worth recording. They should be discarded. The LLM can judge.

The judgement looks like this.
```json
{
  "decision": "RECORD",
  "novelty_type": "mechanism",
  "one_sentence_punchline": "Inserting an LLM-based 'novelty referee' between machine-generated facts and human synthesis filters out low-entropy slop before it contaminates a RAG knowledge base.",
  "confidence": 0.82,
  "reason": "The three-source fusion yields a concrete intervention (a referee prompt) plus a testable prediction (precision ≥ 0.9); this exact recipe does not appear in the prior turns or in standard RAG literature."
}
```

The result is interleaved in the insight for later pruning.
```json
{
  "theme": "Personal Productivity Techniques and Their Pedagogical Effectiveness",
  "understanding": "The Hammertime sequence presents a collection of structured introspection techniques designed to help individuals identify personal inefficiencies and uncover cognitive blind spots, similar to software debugging approaches. These include historical analysis of past successes, simulating external perspectives by role-playing a best friend, and systematic audits of daily routines. However, the author's candid self-assessment reveals that despite creating these innovative techniques, most readers engage only superficially, suggesting a disconnect between theoretically sound rationality frameworks and practical application or engagement.",
  "analysis": "There's a fundamental tension between the author's interest in developing novel rationality techniques and their actual pedagogical impact. The techniques themselves (history search, friend simulation, routine audits) are methodologically sound and potentially valuable, yet the author acknowledges that their sequence may not be superior to existing materials like the CFAR Handbook, indicating a potential over-investment in creating novel content versus curating existing effective methods.",
  "sources": [
    "Daily Challenge to Discover New Techniques",
    "Simulating a Best Friend for Insight",
    "Auditing the Morning Routine for Bugs",
    "Teach Instrumental Rationality Sequence Assessment",
    "Auditing Work or School for Bugs"
  ],
  "questions": "What specific barriers prevented readers from fully engaging with these techniques? How might these methods be repackaged or integrated with existing frameworks to improve adoption and effectiveness?",
  "decision": "REJECT",
  "novelty_type": null,
  "one_sentence_punchline": "A key tension exists between the creation of theoretically sound introspection techniques and their low practical engagement by readers.",
  "confidence": 0.9,
  "reason": "Rejected because the core idea is a juxtaposition of a known concept (introspection techniques) with a well-documented problem (low user engagement), and it does not propose a novel mechanism, reversal, or fusion."
}
```


## Delete and Prune

A delete tool is also exposed for humans or LLM to use. It uses soft deletes,
marking for later removal.

You should perform periodic garbage collection (prune) to periodically remove
atoms marked for deletion before a grace period. There is a tool exposed to do
that also.

***


## Command-line usage of tools

See `$ nwy --help`.

Versions of `distil`, `recall` and `synthesize` are available as cli commands
for use with files and directories as `nwy distil` etc.

LLM-related tools for command-line use. These may be moved to another project.

- `nwy pdf2md`: convert pdf (as image) to markdown
- `nwy pdf2latex`: convert pdf (as image) to latex
- `nwy img2md`: convert image to markdown
- `nwy img2latex`: convert image to latex

- review: Act as a reviewer for a paper (TBD)
- editor: Act as an editor for a paper (TBD)
- proofread: Act as a proofreader for a paper (TBD)


## Components

- noteworthy/cli        [apply tools to files]
- noteworthy/pipeline   [applied templates, use trag/template]
- noteworthy/util       [local utils]
- noteworthy/foundry    [the knowledge distillation and synthesis tools]
- noteworthy/mcp_server [MCP server, exposes knowledge tools]


## Install / upgrade / docker

In your venv,

```bash
$ pip install -U nwy
```

Check the config examples in the `config/` directory, and place them in their
respective directories, `$XDG_CONFIG_HOME/fvdb/` and
`$XDG_CONFIG_HOME/noteworthy`, each as `config.toml`. If you use docker, the
`config` directory here is copied to the image and set as the config home (see
`Dockerfile`). Alternatively, you can mount a docker volume over `/app/config`.


## Other command-line tools

For the distillation step in particular, you might want to use the cli commands.

```bash
$ nwy --help
$ fvdb --help
```


## Acknowledgements

[arxiv-to-prompt](https://https://github.com/takashiishida/arxiv-to-prompt),
[LeoGitGuy.alex-paper-search-mcp](https://github.com/LeoGitGuy/alex-paper-search-mcp/) for the simple and elegant example,
[FastMCP](https://gofastmcp.com).
