# Multiple topics


mutable struct MQTTMultTopics{T} <: AbstractMQTTDevice
    devname::String
    broker::Tuple{String,Int64}
    user::User
    client::Client
    topics::Vector{String}
    tstart::Float64
    buffer::Vector{Vector{Tuple{DateTime,T}}}
    time::Float64
    subscribed::Bool
    alone::Int64
    units::Vector{String}
end


function MQTTMultTopics(devname, topics, ::Type{T}=Float64;
                        broker="192.168.0.180", port=1883,
                        units, user="", password="", atleastone=10) where {T}

    if length(topics) != length(units)
        error("The number of units should correspond to the number of topics")
    end
    
    br = (broker,port)
    us = User(user,password)
    # Make connection
    client, connection = MakeConnection(broker, port; user=us)
    connect(client, connection)
    return MQTTMultTopics{T}(devname, br, us, client, topics, 0.0,
                             Vector{Tuple{DateTime,T}}[], 10.0, false,
                             atleastone, units)
end

ntopics(dev::MQTTMultTopics) = length(dev.topics)


function make_subscription(dev::MQTTMultTopics{T}) where {T}

    dev.buffer = [Tuple{DateTime,T}[] for i in 1:ntopics(dev)]

    on_msg = [(topic, payload) -> begin
                  t = now()
                  s = String(payload)
                  x = parse(T,s)
                  push!(dev.buffer[i], (t,x))
              end
              for i in 1:ntopics(dev)]
    
    for (topic, fun) in zip(dev.topics, on_msg)
        subscribe(dev.client,topic, fun; qos=QOS_2)
    end
    dev.subscribed = true
    dev.tstart = time()

end


function scan!(dev::MQTTMultTopics{T}) where {T}
    make_subscription(dev)
    sleep(dev.time)
    
    if minimum(length.(dev.buffer)) == 0
        # We waited the desired interval but no data was read.
        # We will wait a little longer
        sleep(dev.alone)
    end
    for topic in dev.topics
        unsubscribe(dev.client, topic)
    end
    
    dev.subscribed = false
end


function DAQCore.daqstart(dev::MQTTMultTopics)
    reconnect!(dev)
    Threads.@spawn scan!(dev)
end

function read_topic_data(dev::MQTTMultTopics{T}, k) where {T}

    Nt = length(dev.buffer[k])
    t = [x[1] for x in dev.buffer[k]]
    x = zeros(T, 1, Nt)
    for (i,buf) in enumerate(dev.buffer[k])
        x[1,i] = buf[2]
    end

    S = DaqSamplingTimes(t[1:Nt])
    ch = [dev.topics[k]]

    return MeasData(dev.devname, "MQTTMultTopics", S, x, ch, [dev.units[k]])

end



function DAQCore.daqread(dev::MQTTMultTopics)
    elapsed = time()-dev.tstart
    elapsed < dev.time && sleep(dev.time - elapsed)

    while dev.subscribed
        sleep(1)
    end
    dev.subscribed = false
    # Read the data
    return [read_topic_data(dev, k) for k in 1:ntopics(dev)]
    
    
end

function DAQCore.daqacquire(dev::MQTTMultTopics)
    reconnect!(dev)
    scan!(dev)
    return daqread(dev)
end
