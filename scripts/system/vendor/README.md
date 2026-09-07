KDL-py 1.2.0 (MIT), https://github.com/tabatkins/kdlpy, from the PyPI
kdl_py-1.2.0-py3-none-any.whl distribution. No installation is required.
Local changes in parsefuncs.py: retain source_start/source_end on parsed nodes;
accept the implicit node terminator before `}` supported by niri/knuffel.
Source spans let the editor preserve untouched user text, including comments.
Additional local parser metadata: children_end points at the closing child brace.
Untagged integer mantissas with exponent zero retain Python int precision/type.
