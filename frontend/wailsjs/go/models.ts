export namespace main {
	
	export class Config {
	    localFolder: string;
	    sshConnection: string;
	    remotePath: string;
	    ignoreList: string[];
	    logRetentionMinutes: number;
	
	    static createFrom(source: any = {}) {
	        return new Config(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.localFolder = source["localFolder"];
	        this.sshConnection = source["sshConnection"];
	        this.remotePath = source["remotePath"];
	        this.ignoreList = source["ignoreList"];
	        this.logRetentionMinutes = source["logRetentionMinutes"];
	    }
	}

}

