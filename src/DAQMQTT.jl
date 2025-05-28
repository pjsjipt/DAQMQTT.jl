module DAQMQTT
using DAQCore
using Dates

mutable struct MQTTTopic{T,User} <: AbstractInputDev
    devname::String
    broker::Tuple{String,UInt16}
    user::User
    topic::String
    buffer::Vector{Tuple{DateTime,T}}
    subscribed::Bool
end

end
