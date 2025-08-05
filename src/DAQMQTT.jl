module DAQMQTT

export MQTTTopic, MQTTMultTopics

using MQTTClient

using DAQCore
using Dates

abstract type AbstractMQTTDevice <: AbstractInputDev end

include("single_topic.jl")
include("mult_topic.jl")


end
