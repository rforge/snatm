# Choose which list (help or devel) and which terms (subjects or content) you want to analyse.
list <- "devel"
terms.from <- "subjects"


# Create folder tree
dir.create(list)

# Choose the months you want to analyse.
files <- c("2008-January.txt","2008-February.txt","2008-March.txt","2008-April.txt","2008-May.txt"
          ,"2008-June.txt","2008-July.txt","2008-August.txt","2008-September.txt","2008-October.txt","2008-November.txt","2008-December.txt"
          ,"2009-January.txt","2009-February.txt","2009-March.txt","2009-April.txt","2009-May.txt")


# Download the mailing lists into folter "list"
setInternet2(use = TRUE)
for (i in files){
  download.file(paste("https://stat.ethz.ch/pipermail/r-devel/",i,".gz",sep=""), paste(list,"/",i,sep=""))
}
          
                    
# Write all these e-mails in one file.
filename <- paste(list,"/","allthreads",sep="")
as.one.file(files,filename=paste(filename,".txt",sep=""),list=list)


# Create a forest of the mailing list data stored in filename. Result will be a file named "filename_forest.rda".
forest <- makeforest(filename)
save(forest,file=paste(filename,"_forest.rda",sep=""))


# Find and replace aliases.
load(paste(filename,"_forest.rda",sep=""))
authors <- forest[,3]
a <- normalizeauthors(authors)
b <- sapply(a,sortnames,USE.NAMES=FALSE)
c <- sapply(b,emailfirst,USE.NAMES=FALSE)
# Load databases for aliases that already have been found and have been accpted and not accepted, respectively.
load("take.memory.rda") # First vector element of each list element i (take.memory[[i]][1]) can be replaced by any of the following.
load("not.take.memory.rda") # First vector element of each list element i (not.take.memory[[i]][1]) cannot be replaced by any of the following.
d <- changenames(clusters=take.memory,forest=c,accept=1:length(take.memory))
# clusters is a list where each list element [[i]] contains a vector.
# First vector element is matched string and following elements are matches found.
clusters <- findclusters(unique(d),not.take.memory=not.take.memory)
# if length(clusters>0):
# Manually look at every cluster [[i]] and decide whether to accept it or not.
# Write numbers of accepted clusters like this: accept <- c(1,3,4) (if clusters 1, 3 and 4 are accepted)
# and numbers of not accepted clusters like this: not.accept <- c(2,6) (if clusters 2 and 5 are not accepted)
# and type
# take.memory <- c(take.memory,clusters[accept])
# not.take.memory <- c(not.take.memory,clusters[not.accept])
# save(take.memory,file="take.memory.rda")
# save(not.take.memory,file="not.take.memory.rda")
# to store the new databases.
# Please report any false entries in take.memory or not.take.memory to angela.bohn@gmail.com.
# If clusters contain some aliases that should be accepted and some that should not
# (e.g. "johnsmith|John Smith" "jsmith|John Smith" "jsmithers|John Smithers")
# type
# take.memory <- list(c("johnsmith|John Smith" "jsmith|John Smith" ))
# not.take.memory <- list(c("johnsmith|John Smith","jsmithers|John Smithers"))
# and then
# take.memory <- c(take.memory,take)
# not.take.memory <- c(not.take.memory,not.take)
# save(take.memory,file="take.memory.rda")
# save(not.take.memory,file="not.take.memory.rda")
e <- changenames(clusters,forest=d,accept=accept)
f <- final(e)
# Replace Author-Column in forest and save as forest_corrected
forest_corrected <- cbind(forest[,1:2],f,forest[,4:5])
colnames(forest_corrected)[3] <- colnames(forest)[3]
save(forest_corrected,file=paste(filename,"_forest_corrected.rda",sep=""))


# Build entire communication network
load(file=paste(filename,"_forest_corrected.rda",sep=""))
commlist <- createedges(forest_corrected)
save(commlist,file=paste(list,"/commlist_",list,".rda",sep=""))
commnet <- makematrix(commlist) # might require a lot of working space
save(commnet,file=paste(list,"/commnet_",list,".rda",sep=""))


# Get term frequencies from subjects/content
load(file=paste(filename,"_forest_corrected.rda",sep=""))
colnames(forest_corrected)[4:5] <- c("subjects","content")
termfreq <- tm::Corpus(VectorSource(forest_corrected[,which(colnames(forest_corrected)==terms.from)]))
termfreq <- unlist(mapply(tm::termFreq,termfreq))
termfreq <- termfreq[!is.element(names(termfreq),stopwords())]
words <- names(termfreq)
termfreq <- sort(table(words),decreasing=T)
if (terms.from=="subjects"){
  termfreq <- termfreq[termfreq>9]
}
if (terms.from=="content"){
  termfreq <- termfreq[termfreq>19]
}
save(termfreq,file=paste(list,"/termfreq_",terms.from,".rda",sep=""))


# Create communication networks of all people who used a certain term contained in termfreq_subjects/termfreq_content
# Results are saved as net_terms[i].
load(file=paste(filename,"_forest_corrected.rda",sep=""))
forest_corrected[,4:5] <- base::tolower(forest_corrected[,4:5])
load(file=paste(list,"/termfreq_",terms.from,".rda",sep=""))
dir.create(paste(list,"/",terms.from,sep=""))
extract.commnet(forest_corrected,names(termfreq),apply.on=terms.from)


# Create two-mode network: people and terms
# Result is saved as "peopleandterms_edgelist.rda"
load(file=paste(list,"/termfreq_",terms.from,".rda",sep=""))
edgelist <- centrality.edgelist(terms=names(termfreq),apply.on=terms.from)
save(edgelist,file=paste(list,"/peopleandterms_",terms.from,"_edgelist.rda",sep=""))
net <- makematrix(edgelist,mode="addvalues",directed=F)
save(net,file=paste(list,"/peopleandterms_",terms.from,"_net.rda",sep=""))


# 2-mode plot
# Take gplot from sna version 1.5! gplot from version 2.0-1 contains bugs.
load(file="rhelp/peopleandterms_subjects_net.rda")
load("rhelp/peopleandterms_subjects_edgelist.rda")
peoplelist <- edgelist[,1]
peoplelist <- peoplelist[peoplelist!="data"]
peoplelist <- peoplelist[peoplelist!="dat"]
peoplelist <- peoplelist[peoplelist!="start"]
peoplelist <- peoplelist[peoplelist!="linux"]
twomode <- net
twomode[twomode<0.9955] <- 0
deg <- sna::degree(twomode,cmode="freeman")
twomode <- twomode[,deg>0]
twomode <- twomode[deg>0,]
twomode <- sna::component.largest(twomode,connected="weak",result="graph")
deg <- sna::degree(twomode)
people <- which(is.element(rownames(twomode),unique(peoplelist)))
labelcol <- rep(rgb(0,0,1,0.75),dim(twomode)[1])
labelcol[people] <- "red"
par(mar=c(0,0,0,0))
gplot(twomode
     ,gmode="graph"
     ,vertex.col="white"
     ,vertex.cex=1
     ,label=rownames(twomode)
     ,label.col=labelcol
     ,label.cex=(deg^0.25)*0.35
     ,label.pos=5
     ,boxed.labels=FALSE
     ,edge.lwd=0.1
     ,vertex.border="white"
     ,edge.col="grey")


# Make interest network from 2-mode-network
load(file=paste(list,"/peopleandterms_",terms.from,"_net.rda",sep=""))
load(file=paste(list,"/peopleandterms_",terms.from,"_edgelist.rda",sep=""))
people <- which(is.element(rownames(net),unique(edgelist[,1])))
interestnet <- shrink(net,by="row",keep=people,values="min")
save(interestnet,file=paste(list,"/interestnet_",terms.from,".rda",sep=""))


# Compare communication network and interest network

# Figure 3

load(file="rdevel/interestnet_subjects.rda")
load(file="rdevel/network_red_subjects_permuted.rda")
diag(network_red) <- 0
plot(as.vector(network_red),as.vector(interestnet)
    ,xlab="Number of e-mails"
    ,ylab="Extent of shared interests"
    ,log="x"
    ,col="grey20"#rgb(0.2,0.2,0.2,0.5)
    ,cex.lab=1
    ,cex.axis=1
    ,main="R-devel"
    ,cex.main=1)
    
    
# Figure 4

network_red_ig <- graph.adjacency(network_red, mode="directed")
save(network_red_ig,file="rhelp/network_red_subjects_permuted_ig.rda")
write.graph(network_red_ig,file="rhelp/network_red_subjects_permuted.net",format="pajek")
# Calculate closeness with pajek because network_red is not connected
clo <- read.table("rhelp/network_red_subjects_permuted_closeness.txt",skip=1)
clo <- as.vector(as.matrix(clo))
deg <- sna::degree(network_red,cmode="freeman",gmode="graph",ignore.eval=TRUE)
#betw <- igraph::betweenness(network_red_ig,directed=F)
#pr <- igraph::page.rank(network_red_ig,directed=F)$vector
centm <- list(deg,betw,clo,pr)
save(centm,file="rhelp/network_red_subjects_permuted_centm.rda")

network_red_ig <- graph.adjacency(network_red, mode="directed")
save(network_red_ig,file="rhelp/network_red_content_permuted_ig.rda")
write.graph(network_red_ig,file="rhelp/network_red_content_permuted.net",format="pajek")
clo <- read.table(file="rhelp/network_red_content_permuted_closeness.txt",skip=1)
clo <- as.vector(as.matrix(clo))
deg <- sna::degree(network_red,cmode="freeman",gmode="graph",ignore.eval=TRUE)
#betw <- igraph::betweenness(network_red_ig,directed=F)
#pr <- igraph::page.rank(network_red_ig,directed=F)$vector
centm <- list(deg,betw,clo,pr)
save(centm,file="rhelp/network_red_content_permuted_centm.rda")

network_red_ig <- graph.adjacency(network_red, mode="directed")
save(network_red_ig,file="rdevel/network_red_subjects_permuted_ig.rda")
write.graph(network_red_ig,file="rdevel/network_red_subjects_permuted.net",format="pajek")
clo <- read.table("rdevel/network_red_subjects_permuted_closeness.txt",skip=1)
clo <- as.vector(as.matrix(clo))
deg <- sna::degree(network_red,cmode="freeman",gmode="graph",ignore.eval=TRUE)
#betw <- igraph::betweenness(network_red_ig,directed=F)
#pr <- igraph::page.rank(network_red_ig,directed=F)$vector
centm <- list(deg,betw,clo,pr)
save(centm,file="rdevel/network_red_subjects_permuted_centm.rda")

network_red_ig <- graph.adjacency(network_red, mode="directed")
save(network_red_ig,file="rdevel/network_red_content_permuted_ig.rda")
write.graph(network_red_ig,file="rdevel/network_red_content_permuted.net",format="pajek")
clo <- read.table("rdevel/network_red_content_permuted_closeness.txt",skip=1)
clo <- as.vector(as.matrix(clo))
deg <- sna::degree(network_red,cmode="freeman",gmode="graph",ignore.eval=TRUE)
#betw <- igraph::betweenness(network_red_ig,directed=F)
#pr <- igraph::page.rank(network_red_ig,directed=F)$vector
centm <- list(deg,betw,clo,pr)
save(centm,file="rdevel/network_red_content_permuted_centm.rda")

load(file="rhelp/network_red_subjects_permuted.rda")
diag(network_red) <- 0
load(file="rhelp/interestnet_subjects.rda")
par(mfrow=c(1,2),mar=c(4,4,4,0.5))
load(file="rhelp/network_red_subjects_permuted_centm.rda")
for (k in seq_along(centm)){
  a <- seq(0,max(centm[[k]]),by=max(centm[[k]])/100)
  c <- c()
  for (i in a){
    b <- cor(as.vector(interestnet[centm[[k]]>=i,centm[[k]]>=i]),as.vector(network_red[centm[[k]]>=i,centm[[k]]>=i]))
    if (!is.na(b)){
      c <- c(c,b)
    }
  }
  names(c) <- seq(0,max(centm[[k]]),length.out=length(c))
  d <- unique(c)
  for (i in seq_along(d)){
    names(d)[i] <- which(d[i]==c)[1]
  }
  x <- as.numeric(names(d))
  names(d) <- as.character((x-min(x))/(max(x)-min(x)))
  plot(as.numeric(names(d)),d
      ,ylab="Correlation"
      ,cex.lab=1
      ,ylim=c(0,1)
      ,cex.axis=1
      ,main="R-help subjects"
      ,cex.main=1
      ,xlab=""
      ,col=c("skyblue3","blue","darkblue","black")[k]
      ,type="l"
      ,lwd=3
      ,lty=c(1,2,3,4)[k])
  par(new=T,yaxt="n",xaxt="n")
}
text(labels=paste("n=",dim(network_red)[1],sep=""),x=0.15,y=1)

load(file="rhelp/network_red_content_permuted.rda")
diag(network_red) <- 0
load(file="rhelp/interestnet_content.rda")
par(yaxt="s",xaxt="s")
load(file="rhelp/network_red_content_permuted_centm.rda")
for (k in seq_along(centm)){
  a <- seq(0,max(centm[[k]]),by=max(centm[[k]])/100)
  c <- c()
  for (i in a){
    b <- cor(as.vector(interestnet[centm[[k]]>=i,centm[[k]]>=i]),as.vector(network_red[centm[[k]]>=i,centm[[k]]>=i]))
    if (!is.na(b)){
      c <- c(c,b)
    }
  }
  names(c) <- seq(0,max(centm[[k]]),length.out=length(c))#,by=max(centm[[k]])/100)
  d <- unique(c)
  for (i in seq_along(d)){
    names(d)[i] <- which(d[i]==c)[1]
  }
  x <- as.numeric(names(d))
  names(d) <- as.character((x-min(x))/(max(x)-min(x)))
  plot(as.numeric(names(d)),d
      ,ylab=""
      ,ylim=c(0,1)
      ,cex.lab=1
      ,cex.axis=1
      ,main="R-help content"
      ,cex.main=1
      ,xlab=""
      ,col=c("skyblue3","blue","darkblue","black")[k]
      ,type="l"
      ,lwd=3
      ,lty=c(1,2,3,4)[k])
  par(new=T,yaxt="n",xaxt="n")
}
text(labels=paste("n=",dim(network_red)[1],sep=""),x=0.15,y=1)

load(file="rdevel/network_red_subjects_permuted.rda")
diag(network_red) <- 0
load(file="rdevel/interestnet_subjects.rda")
par(mfrow=c(1,2),mar=c(4,4,4,0.5))
load(file="rdevel/network_red_subjects_permuted_centm.rda")
for (k in seq_along(centm)){
  a <- seq(0,max(centm[[k]]),by=max(centm[[k]])/100)
  c <- c()
  for (i in a){
    b <- cor(as.vector(interestnet[centm[[k]]>=i,centm[[k]]>=i]),as.vector(network_red[centm[[k]]>=i,centm[[k]]>=i]))
    if (!is.na(b)){
      c <- c(c,b)
    }
  }
  names(c) <- seq(0,max(centm[[k]]),length.out=length(c))#,by=max(centm[[k]])/100)
  d <- unique(c)
  for (i in seq_along(d)){
    names(d)[i] <- which(d[i]==c)[1]
  }
  x <- as.numeric(names(d))
  names(d) <- as.character((x-min(x))/(max(x)-min(x)))
  plot(as.numeric(names(d)),d
      ,ylab=paste("Correlation")
      ,cex.lab=1
      ,cex.axis=1
      ,main="R-devel subjects"
      ,cex.main=1
      ,xlab="Centrality"
      ,col=c("skyblue3","blue","darkblue","black")[k]
      ,type="l"
      ,ylim=c(0,1)
      ,lwd=3
      ,lty=c(1,2,3,4)[k])
  par(new=T,yaxt="n",xaxt="n")
}
text(labels=paste("n=",dim(network_red)[1],sep=""),x=0.15,y=1)

load(file="rdevel/network_red_content_permuted.rda")
diag(network_red) <- 0
load(file="rdevel/interestnet_content.rda")
par(yaxt="s",xaxt="s")
load(file="rdevel/network_red_content_permuted_centm.rda")
for (k in seq_along(centm)){
  a <- seq(0,max(centm[[k]]),by=max(centm[[k]])/100)
  c <- c()
  for (i in a){
    b <- cor(as.vector(interestnet[centm[[k]]>=i,centm[[k]]>=i]),as.vector(network_red[centm[[k]]>=i,centm[[k]]>=i]))
    if (!is.na(b)){
      c <- c(c,b)
    }
  }
  names(c) <- seq(0,max(centm[[k]]),length.out=length(c))
  d <- unique(c)
  for (i in seq_along(d)){
    names(d)[i] <- which(d[i]==c)[1]
  }
  x <- as.numeric(names(d))
  names(d) <- as.character((x-min(x))/(max(x)-min(x)))
  plot(as.numeric(names(d)),d
      ,ylab=""
      ,cex.lab=1
      ,cex.axis=1
      ,main="R-devel content"
      ,cex.main=1
      ,xlab="Centrality"
      ,col=c("skyblue3","blue","darkblue","black")[k]
      ,type="l"
      ,lwd=3
      ,ylim=c(0,1)
      ,lty=c(1,2,3,4)[k])
  par(new=T,yaxt="n",xaxt="n")
}
text(labels=paste("n=",dim(network_red)[1],sep=""),x=0.15,y=1)

par(mar=c(0,0,0,0))
plot(1,1,col="transparent",ann=F,axes=F)
legend(legend=c("Degree","Betweenness","Closeness","Pagerank")
      ,x="center"
      ,col=c("skyblue3","blue","darkblue","black")
      ,lty=c(1,2,3,4)
      ,lwd=3
      ,bty="n"
      ,horiz=T)


# Figure 5

load("rhelp/allthreads_forest_corrected.rda")
ansquest <- ans.quest(forest_corrected)
save(ansquest,file="rhelp/ansquest.rda")
load("rhelp/network_red_subjects_permuted_centm.rda")
load("rhelp/network_red_subjects_permuted.rda")
deg <- cbind(rownames(network_red),centm[[1]])
cent <- c()
for (i in 1:dim(deg)[1]){
  cent <- rbind(cent
  ,c(as.numeric(ansquest[deg[i,1]==ansquest[,1],2])
    ,as.numeric(ansquest[deg[i,1]==ansquest[,1],3])))
}
cent <- cbind(cent,as.numeric(deg[,2]))
rownames(cent) <- deg[,1]
colnames(cent) <- c("questions","answers","deg")
save(cent,file="rhelp/network_red_subjects_permuted_cent.rda")

load("rdevel/allthreads_forest_corrected.rda")
ansquest <- ans.quest(forest_corrected)
save(ansquest,file="rdevel/ansquest.rda")
load("rdevel/network_red_subjects_permuted_centm.rda")
load("rdevel/network_red_subjects_permuted.rda")
deg <- cbind(rownames(network_red),centm[[1]])
cent <- c()
for (i in 1:dim(deg)[1]){
  cent <- rbind(cent
  ,c(as.numeric(ansquest[deg[i,1]==ansquest[,1],2])
    ,as.numeric(ansquest[deg[i,1]==ansquest[,1],3])))
}
cent <- cbind(cent,as.numeric(deg[,2]))
rownames(cent) <- deg[,1]
colnames(cent) <- c("questions","answers","deg")
save(cent,file="rdevel/network_red_subjects_permuted_cent.rda")

par(mfrow=c(1,2),mar=c(4.2,4,3,0.5))
load(file="rhelp/network_red_subjects_permuted_cent.rda")
deg <- normalize(cent[,3])
col <- rep("black",dim(cent)[1])
col[deg>0.4] <- "red"
plot(cent[,1],cent[,2],cex=deg*5,col=col,xlab="Number of questions",ylab="Number of answers",main="R-help")

load(file="rdevel/network_red_subjects_permuted_cent.rda")
deg <- normalize(cent[,3])
col <- rep("black",dim(cent)[1])
col[deg>0.2] <- "red"
plot(cent[,1],cent[,2],cex=deg*5,col=col,ylab="",xlab="Number of questions",main="R-devel")