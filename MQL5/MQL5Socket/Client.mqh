#include "SocketLib.mqh"

class SocketClient{
   private:
      ref_sockaddr srvaddr;
   public:
      SOCKET64 client;
      SocketClient();
      ~SocketClient();
      bool Start(string addr,ushort port);
      void Close();
      bool Send(string text);
      int intRecv(uchar &rdata[]);
      string Recv();
      
};

SocketClient::SocketClient(void){
   client=INVALID_SOCKET64;
}

SocketClient::~SocketClient(void){
   this.Close();
}

bool SocketClient::Start(string addr,ushort port){
   // inicializar a biblioteca com WSAStartup()
   int res=0;
   char wsaData[]; ArrayResize(wsaData, sizeof(WSAData));
   res=WSAStartup(MAKEWORD(2,2), wsaData);
   if (res!=0){ 
      Print("-WSAStartup failed error: "+string(res)); 
      return false; 
   }

   // criar uma soquete com socket();
   client=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
   if(client==INVALID_SOCKET64){
      Print("-Create failed error: "+WSAErrorDescript(WSAGetLastError())); 
      this.Close();
      return false; 
   }
   char ch[]; StringToCharArray(addr,ch);
   sockaddr_in addrin;
   addrin.sin_family=AF_INET;
   addrin.sin_addr.u.S_addr=inet_addr(ch);
   addrin.sin_port=htons(port);

    // conectar ao servidor com connect();
   ref_sockaddr ref; ref.in=addrin;
   res=connect(client,ref.ref,sizeof(addrin));
   if(res==SOCKET_ERROR){
      int err=WSAGetLastError();
      if(err!=WSAEISCONN){
         //Print("-Connect failed error: "+WSAErrorDescript(err));
         this.Close();
         return false; 
      }
   }

   // Configurar no modo de não bloqueio com ioctlsocket(), a fim de não congelar enquanto aguarda os dados
   int non_block=1;
   res=ioctlsocket(client,(int)FIONBIO,non_block);
   if(res!=NO_ERROR){ 
      //Print("ioctlsocket failed error: "+string(res)); 
      this.Close(); 
      return false; 
   }

   Print("Connect OK");
   return true;
}

bool SocketClient::Send(string text){
   if(client==INVALID_SOCKET64) return false;
   
   uchar data[]; StringToCharArray(text,data);
   if(sendto(client,data,ArraySize(data),0,srvaddr.ref,ArraySize(srvaddr.ref))==SOCKET_ERROR){
         int err=WSAGetLastError();
         if(err!=WSAEWOULDBLOCK){
            //Print("-Send failed error: "+WSAErrorDescript(err)); 
            this.Close();
            return false;
        }
   }
   Print("Send: ", text);
   return true;
}


string SocketClient::Recv(){
   string msg = "";

   uchar buf[];
   int resp = this.intRecv(buf);
   if(resp == SOCKET_ERROR) return msg;
   if(resp >0){
      msg+=CharArrayToString(buf); 
      Print("Recv: ", msg);    
   }
   return msg;    
}

void SocketClient::Close(void){
   if(client!=INVALID_SOCKET64){
      if(shutdown(client,SD_BOTH)==SOCKET_ERROR)
         //Print("-Shutdown failed error: "+WSAErrorDescript(WSAGetLastError()));
      closesocket(client); 
      client=INVALID_SOCKET64;
   }
   WSACleanup();
}

int SocketClient::intRecv(uchar &rdata[]){
   if(client==INVALID_SOCKET64) return 0;

   char rbuf[512]; int rlen=512; int r=0,res=0;
   do{
      res=recv(client,rbuf,rlen,0);
      if(res<0){
         int err=WSAGetLastError();
         if(err!=WSAEWOULDBLOCK){
            Print("-Receive failed error: "+string(err)+" "+WSAErrorDescript(err));
            this.Close();
            return -1; 
         }
         break;
      }
      if(res==0 && r==0){
         Print("-Receive. connection closed");
         this.Close();
         return -1; 
      }
      r+=res; ArrayCopy(rdata,rbuf,ArraySize(rdata),0,res);
   } while(res>0 && res>=rlen);
   return r;
}