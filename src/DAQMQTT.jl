module DAQMQTT

using MQTTClient

using DAQCore
using Dates

mutable struct MQTTTopic{T,U} <: AbstractInputDev
    devname::String
    broker::Tuple{String,UInt16}
    user::U
    topic::String
    buffer::Vector{Tuple{DateTime,T}}
    time::Float64
    subscribed::Bool
end

function DAQCore.daqconfig(dev::MQTT, time)
    time < 0 &&  error("Time should be a positive number of seconds!")
    time > 10_000 && error("Time is too large. In this framework it should be a couple of minute...")
    
    dev.time = time
end

function DAQCore.daqstart(dev::MQTT)
    empty!(dev.buffer())
    
end


function DAQCore.daqread(dev::MQTT)
end

function 
end
