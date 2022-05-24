import vibe.http.server;
import vibe.http.router;
import vibe.http.client;
import vibe.stream.operations;
import vibe.web.rest;
import vibe.data.json;
import vibe.data.serialization;
import vibe.core.core : runApplication;
import vibe.core.log;
import std.typecons;
import std.array;
import std.algorithm;
import std.string;
import std.conv;
import std.random;
import std.json;
import std.process : environment;
import tinyredis;

@path("/api/") interface MyShiftAPI {
	@safe string getMyshift();
	Json addMyshift(@viaBody("team") string[] team, 
			@viaBody("notificationUrl") string notificationUrl,
			@viaBody("avatarUrl") string avatarUrl,
			@viaBody("themeColor") string themeColor,
			@viaBody("titleMessage") string titleMessage,
			@viaBody("bodyMessage") string bodyMessage);
	string getSetmyshift(@viaQuery("shift") int shift);
	string getUpdatemyshift();
	Json getSendmyshift();
	@safe string getHealth();
}

class MyShiftAPIService : MyShiftAPI {

	@safe string getMyshift()
	{
		return("Send me a POST request with the shift configuration");
	}

	string getSetmyshift(@viaQuery("shift") int shift)
	{
 		auto redis_host = environment.get("REDIS_HOST", "127.0.0.1");
    		auto redis_port = to!ushort(environment.get("REDIS_PORT", "6379"));
		auto redis = new Redis(redis_host, redis_port);
		auto maxShift=to!int(redis.send("LLEN", "team"));
		if (( 0 <= shift ) && (shift < maxShift )) {
			redis.send("SET", "shift", shift);
			redis.send("QUIT");
			return(format("Set shift to %d", shift));
		} else {
			redis.send("QUIT");
			return(format("Shift position %d doesn't exist", shift));
		}
	}

	string getUpdatemyshift()
	{
		int shift;
 		auto redis_host = environment.get("REDIS_HOST", "127.0.0.1");
    		auto redis_port = to!ushort(environment.get("REDIS_PORT", "6379"));
		auto redis = new Redis(redis_host, redis_port);
		auto currentShift=to!int(redis.send("GET", "shift"));
		auto maxShift=to!int(redis.send("LLEN", "team"));
		if ( currentShift < maxShift-1 ) {
			shift=currentShift+1;
		} else {
			shift=0;
		}
		redis.send("SET", "shift", shift);
		redis.send("QUIT");
		return(format("Set shift to %d", shift));
	}

	Json addMyshift(@viaBody("team") string[] team,
			@viaBody("notificationUrl") string notificationUrl,
			@viaBody("avatarUrl") string avatarUrl,
			@viaBody("themeColor") string themeColor,
			@viaBody("titleMessage") string titleMessage,
			@viaBody("bodyMessage") string bodyMessage)
	{
		Json returnMessage;

		auto redis_host = environment.get("REDIS_HOST", "127.0.0.1");
   	 	auto redis_port = to!ushort(environment.get("REDIS_PORT", "6379"));
		auto redis = new Redis(redis_host, redis_port);

		redis.send("SET", "shift", "0");
		redis.send("DEL", "team");
		for (int i = 0; i < team.length; ++i) {
			redis.send("RPUSH", "team", team[i]);
		}
		redis.send("SET", "notificationUrl", notificationUrl);
		redis.send("SET", "avatarUrl", avatarUrl);
		redis.send("SET", "themeColor", themeColor);
		redis.send("SET", "titleMessage", titleMessage);
		redis.send("SET", "bodyMessage", bodyMessage);
		redis.send("QUIT");
		returnMessage = Json( "Created/updated configuration" );

		return(returnMessage);
	}
	Json getSendmyshift()
	{
		int shift;
		Json returnMessage;
 		auto redis_host = environment.get("REDIS_HOST", "127.0.0.1");
    		auto redis_port = to!ushort(environment.get("REDIS_PORT", "6379"));
		auto redis = new Redis(redis_host, redis_port);
		auto currentShift=to!int(redis.send("GET", "shift"));
		auto buddy=to!string(redis.send("LINDEX", "team", currentShift));
		auto notificationUrl=to!string(redis.send("GET", "notificationUrl"));
		auto avatarUrl=to!string(redis.send("GET", "avatarUrl"));
		auto themeColor=to!string(redis.send("GET", "themeColor"));
		auto bodyMessage=to!string(redis.send("GET", "bodyMessage"));
		auto titleMessage=to!string(redis.send("GET", "titleMessage"));

		struct Fact {
			string name;
			string value;
		}
		struct Section {
			string activityTitle;
			string activityImage;
			Fact[] facts;
			bool markdown;
		}

		auto fact0 = Fact(bodyMessage, buddy);
		auto section0 = Section(titleMessage, avatarUrl, [fact0], true);
		Json invitationCard = Json.emptyObject;
		invitationCard["@type"] = "MessageCard";
		invitationCard["@context"] = "http://schema.org/extensions";
		invitationCard["summary"] = "Current shift";
		invitationCard["themeColor"]= themeColor;
		invitationCard["sections"]=[section0.serializeToJson()];
		// Would be nice serializing invitationCard from a struct but there is a issue with keys beginning with an '@'
		requestHTTP(notificationUrl,
			(scope req) {
				req.method = HTTPMethod.POST;
				req.writeJsonBody(invitationCard);
			},
			(scope res) {
				logInfo("Webhook URL: %s Status code: %s Response: %s", notificationUrl, res.statusCode, res.bodyReader.readAllUTF8());
			}
		);
		redis.send("QUIT");
		returnMessage=Json(format("Sent shift reminder to: %s",  buddy));
		return(returnMessage);
	}

	@safe string getHealth()
	{
		return("Healthy!");
	}
}

// API for sandboxing webhook endpoints. We can put MS Teams API
//validations here, but we simply send "sections" to the app log

@path("/sandbox/") interface SandboxAPI {
	@safe Json addTest(Json sections);
}


class SandboxAPIService : SandboxAPI {
	@safe Json addTest(Json sections)
	{
		return(sections);
	}
}

// Main process
void main()
{

    auto settings = new HTTPServerSettings;
    auto router = new URLRouter;

    router.registerRestInterface(new MyShiftAPIService);
    router.get("/", (req, res) { res.redirect("/sandbox/test"); } );
    router.get("/api/", (req, res) { res.redirect("/api/myshift"); } );

    router.registerRestInterface(new SandboxAPIService);

    auto host = environment.get("MYSHIFT_HOST", "127.0.0.1");
    auto port = to!ushort(environment.get("MYSHIFT_PORT", "9000"));

    settings.port = port;
    settings.bindAddresses = [host];
    settings.errorPageHandler = (req, res, error)
         {
              with(error) res.writeBody(
              format("Code: %s\n Message: %s\n Exception: %s",
              error.code, 
              error.message, 
              error.exception ? error.exception.msg : "¡Petó como una rata!"));
         };  
    auto l = listenHTTP(settings, router);
    scope (exit) l.stopListening();
    runApplication();
}
