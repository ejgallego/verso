import VersoBlueprint.Macros

tex_prelude r#"
% These are defined by KaTeX already
% \newcommand{\R}{\mathbb{R}}
% \newcommand{\Z}{\mathbb{Z}}
\newcommand{\C}{\mathbb{C}}
% \newcommand{\N}{\mathbb{N}}
\newcommand{\h}{\mathfrak{H}}
\newcommand{\B}{\mathcal{B}}
\newcommand{\Pa}{\mathcal{P}}
\newcommand{\Vol}[1]{\operatorname{Vol}\!\left(#1\right)}
\newcommand{\Bd}[1]{\B_d\!\left(#1\right)}
\newcommand{\dd}{\mathrm{d}}
\newcommand{\rad}{\mathrm{rad}}
% \newcommand{\set}[1]{\left\{ #1 \right\}}
\newcommand{\setof}[2]{\left\{ #1 \,\mid\, #2 \right\}}
\newcommand{\abs}[1]{\left\lvert #1 \right\rvert}
\newcommand{\norm}[1]{\left\lVert #1 \right\rVert}
\newcommand{\ang}[1]{\left\langle #1 \right\rangle}
\newcommand{\eps}{\varepsilon}
"#
