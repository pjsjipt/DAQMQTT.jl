mutable struct MQTTTopic{T} <: AbstractMQTTDevice
    devname::String
    broker::Tuple{String,Int64}
    user::User
    client::Client
    topic::String
    tstart::Float64
    buffer::Vector{Tuple{DateTime,T}}
    time::Float64
    subscribed::Bool
    alone::Int64
    unit::String
end

function MQTTTopic(devname, topic, ::Type{T}=Float64; broker="192.168.0.180", port=1883,
                   unit, user="", password="", atleastone=10) where {T}
    br = (broker,port)
    us = User(user,password)
    # Make connection
    if user==""
        client, connection = MakeConnection(broker, port)
    else
        client, connection = MakeConnection(broker, port; user=us)
    end
    
    connect(client, connection)
    return MQTTTopic{T}(devname, br, us, client, topic, 0.0,
                        Tuple{DateTime,T}[], 10.0, false, atleastone, unit)
end

function reconnect!(dev::AbstractMQTTDevice)
    broker = dev.broker[1]
    port = dev.broker[2]
    if dev.user.name == ""
        client, connection = MakeConnection(broker, port)
    else
        client, connection = MakeConnection(broker, port; user=dev.user)
    end
    connect(client, connection)
    dev.client = client
    return
end



function DAQCore.daqconfigdev(dev::AbstractMQTTDevice; time=10)
    time <= 0 &&  error("Time should be a positive number of seconds!")
    time > 10_000 && error("Time is too large. In this framework it should be a couple of minute...")
    dev.time = time
end

function make_subscription(dev::MQTTTopic{T}) where {T}

    dev.buffer = Tuple{DateTime,T}[]
    on_msg = (topic, payload) -> begin
        t = now()
        s = String(payload)
        x = parse(T,s)
        push!(dev.buffer, (t,x))
    end
    dev.subscribed = true
    dev.tstart = time()
    subscribe(dev.client, dev.topic, on_msg; qos=QOS_2)
end

        
        

function scan!(dev::MQTTTopic{T}) where {T}
    make_subscription(dev)
    sleep(dev.time)
    
    if length(dev.buffer) == 0
        # We waited the desired interval but no data was read.
        # We will wait a little longer
        sleep(dev.alone)
    end
    unsubscribe(dev.client, dev.topic)
    dev.subscribed = false
end


DAQCore.samplesread(dev::MQTTTopic) = length(dev.buffer)
DAQCore.isreading(dev::MQTTTopic) = dev.subscribed
DAQCore.numchannels(dev::MQTTTopic) = 1
DAQCore.issamplesavailable(dev::MQTTTopic) = length(dev.buffer) > 0


function DAQCore.daqstart(dev::MQTTTopic)
    reconnect!(dev)
    Threads.@spawn scan!(dev)
end


function read_topic_data(dev::MQTTTopic{T}) where {T}

    Nt = length(dev.buffer)
    t = [x[1] for x in dev.buffer]
    x = zeros(T, 1, Nt)
    for i in 1:Nt
        x[1,i] = dev.buffer[i][2]
    end

    S = DaqSamplingTimes(t[1:Nt])
    ch = [dev.topic]

    return MeasData(dev.devname, "MQTTTopic", S, x, ch, [dev.unit])

end


function DAQCore.daqread(dev::MQTTTopic)
    elapsed = time()-dev.tstart
    elapsed < dev.time && sleep(dev.time - elapsed)

    while dev.subscribed
        sleep(1)
    end
    dev.subscribed = false
    # Read the data
    return read_topic_data(dev)
    
    
end

function DAQCore.daqacquire(dev::MQTTTopic)
    reconnect!(dev)

    scan!(dev)
    return daqread(dev)
end
