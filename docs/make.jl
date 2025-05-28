using DAQMQTT
using Documenter

DocMeta.setdocmeta!(DAQMQTT, :DocTestSetup, :(using DAQMQTT); recursive=true)

makedocs(;
    modules=[DAQMQTT],
    authors="= <pjabardo@ipt.br> and contributors",
    sitename="DAQMQTT.jl",
    format=Documenter.HTML(;
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
