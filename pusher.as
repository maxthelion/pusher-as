public class Pusher(app_id){
	private var channels:ChannelFactory;
	private var connected:Boolean;
	private var server; // what type of object is this?
	private var global_channel:Channel
	
	function connect():void {
		channels = new ChannelFactory();
		global_channel = new Channel();
		connectSocket();
		
		bind('pusher:connection_established', function(data) {
			connected = true;
			//self.retry_counter = 0;
			socket_id = data.socket_id;
		});
	}
	
	public function bind(event_name, callback):void {
		this.global_channel.bind(event_name, callback)
		return this;
	}

	private function connectSocket():void{
		var url:String = "ws://ws.pusherapp.com:80/app/YourPusherKey";
		var protocol:String = null; //I really don't know what this 'protocol' is

		var main:WebSocketMain = new WebSocketMain();
		main.setCallerUrl('http://localhost:3000');

		server = main.create(url, protocol);
		server.addEventListener(Event.OPEN, onOpen);
		server.addEventListener(Event.CLOSE, onClose);
		server.addEventListener("message", onMessage);
		server.addEventListener("stateChange", onStateChange);
	}
	
	// subscribe to a given channel
	// TODO: should handle private channels and presence channels in future
	function subscribe(channelName:String):Channel {
		var myChannel:Channel = this.channels.add(channelName);
		
		var pusherData:Object = new Object();
		pusherData.channel = channelName;

		var pusherEvent:Object = new Object();
		pusherEvent.event = 'pusher:subscribe';
		pusherEvent.data	= pusherData;

		var msg:String = JSON.encode(pusherEvent);

		server.send(msg);
		
		return myChannel;
	}
	
	// respond to messages coming ing and route them as necessary
	private function onMessage( event:WebSocketMessageEvent ):void {
		//Example: {"event":"pusher:connection_established","data":"{\"socket_id\":\"1234\"}"}
		var msg:String = decodeURIComponent(event.data);

		var pusherEvent:Object = JSON.decode(msg);
		var pusherData:Object	= JSON.decode(pusherEvent.data); // not always json, so we have a parser in our code
		if (pusherEvent.socket_id && pusherEvent.socket_id == this.socket_id) return;
		sendLocalEvent(pusherEvent.event, pusherData);
	}
	
	function sendLocalEvent(eventName, eventData, channelName){
		 if (channelName) {
			 var channel:Channel = this.channels.find(channelName);
			 if (channel) {
				 channel.dispatch_with_all(event_name, event_data);
			 }
		 }
		 this.global_channel.dispatch_with_all(event_name, event_data);
	}
}

public class ChannelFactory(){
	channels = {};

	function add(channel_name) {
		var existing_channel = this.find(channel_name);
		if (!existing_channel) {
			var channel = new Pusher.Channel();
			this.channels[channel_name] = channel;
			return channel;
		} else {
			return existing_channel;
		}
	}

	function find(channel_name) {
		return this.channels[channel_name];
 	}

	function remove(channel_name) {
		delete this.channels[channel_name];
	}

}

class Channel(){
	private var callbacks = {};
	
	public function bind(event_name:String, callback:Object) {
		this.callbacks[event_name] = this.callbacks[event_name] || [];
		this.callbacks[event_name].push(callback);
		return this;
	}

	public function dispatch_with_all(event_name:String, data:Object) {
		this.dispatch(event_name, data);
	}

	private function dispatch(event_name:String, event_data:Object) {
		var callbacks = this.callbacks[event_name];

		if (callbacks) {
			for (var i = 0; i < callbacks.length; i++) {
				callbacks[i](event_data);
			}
		} 
	}
}

// Potential usage

var pusher:Pusher = new Pusher();
pusher.connect();
myChannel:Channel = pusher.subscribe('foo');
myChannel.bind('myevent' function(){ trace('blah') })