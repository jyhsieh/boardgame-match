library(tidyverse)
library(ggplot2)
library(Rtsne)
library(wordcloud2)
#=========================================================================
# Read Data
#=========================================================================
boardgame <- read_csv("C:\\Users\\nishi\\OneDrive\\Kaggle\\BoardGame\\bgg_db_2018_01.csv")
head(boardgame)
colnames(boardgame)
dim(boardgame)

#=========================================================================
# EDA
#=========================================================================

# boardgame = boardgame[!duplicated(boardgame$names),]
# boardgame <- na.omit(boardgame)
sort(boardgame$year)
boardgame[which(boardgame$year==-3000),] %>% View()
temp = boardgame %>% filter(year>1980) %>% group_by(year) %>% summarise(n=n(), own=sum(owned))
boardgame %>% filter(year>1980) %>% group_by(year) %>% summarise(n=n()) %>% ggplot(aes(year,n)) + geom_area() + ylab("game count")
boardgame %>% filter(year>1980) %>% group_by(year) %>% summarise(own=sum(owned)) %>% ggplot(aes(year,own)) + geom_area() + ylab("game owned")
plot(temp$year,temp$own,type = "l",xlab="year",ylab="game owned")
boardgame %>% ggplot(aes(num_votes,owned)) + geom_point(color=boardgame$age+1)

boxplot(boardgame$age)
boxplot(boardgame$weight)
boardgame %>% ggplot(aes(weight)) + geom_density()
summary(boardgame$weight)
boardgame[which.min(boardgame$weight),4]
#=========================================================================
#=========================================================================




#=========================================================================
# Expand Mechanic and Category Variable
#=========================================================================
All_mechanic = unlist(strsplit(boardgame$mechanic, ", "))
Uniq_mechanic = unique(All_mechanic)
All_cat = unlist(strsplit(boardgame$category, ", "))
Uniq_cat = unique(All_cat)

# mechanic_df = as.data.frame(sapply(Uniq_mechanic, function(x) grepl(x, boardgame$mechanic)*1))
# category_df = as.data.frame(sapply(Uniq_category, function(x) grepl(x, boardgame$category)*1))
# boardgame_cluster = cbind(boardgame, mechanic_df, category_df)

boardgame_cluster <- matrix(0,nrow = dim(boardgame)[1],ncol = length(Uniq_mechanic)+length(Uniq_cat))

for(i in 1:length(Uniq_mechanic)){
  boardgame_cluster[,i] <- grepl(Uniq_mechanic[i],boardgame$mechanic)*1
}
for(i in 1:length(Uniq_cat)){
  boardgame_cluster[,length(Uniq_mechanic)+i] <- grepl(Uniq_cat[i],boardgame$category)*1
}
dim(boardgame_cluster) # 4999 136
boardgame_cluster <- as.data.frame(boardgame_cluster)
colnames(boardgame_cluster)[1:length(Uniq_mechanic)] <- Uniq_mechanic
colnames(boardgame_cluster)[(1+length(Uniq_mechanic)):136] <- Uniq_cat
colnames(boardgame_cluster)
#boardgame_cluster %>% View()
colnames(boardgame_cluster)[which(duplicated(colnames(boardgame_cluster)))] #"none"   "Memory"
which(colnames(boardgame_cluster)=="none") #50 114
colnames(boardgame_cluster)[50] <- "none_mechanic"
colnames(boardgame_cluster)[114] <- "none_cat"
which(colnames(boardgame_cluster)=="Memory") # 26 117
colnames(boardgame_cluster)[26] <- "Memory_mechanic"
colnames(boardgame_cluster)[117] <- "Memory_cat"
colnames(boardgame_cluster)[1:20]
# boardgame <- scale(boardgame)

#boardgame_cluster <- unique(boardgame_cluster)
#=========================================================================
# Clustering (K-means)
#=========================================================================
n_cluster <- 3

set.seed(123)
kmean_result <- kmeans(boardgame_cluster,centers = n_cluster)
#boardgame_cluster['cluster'] <- kmean_result$cluster

#========================================================
# cluster determined by max mode
#========================================================
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

cluster_max <- function(dat,n_cluster,num_iter){
  result <- matrix(0,nrow = dim(dat)[1],ncol = num_iter)
  for(i in 1:num_iter){
    result[,i] <- kmeans(dat,centers = n_cluster)$cluster
  }
  return(apply(result,MARGIN = 1,getmode))
}
#========================================================
#========================================================
cluster_result <- cluster_max(boardgame_cluster,n_cluster = n_cluster,num_iter = 100)


#========================================================
# Visualize clusters
#========================================================
# Visualize through t-sne
set.seed(123)
tsne_out <- Rtsne(as.matrix(unique(boardgame_cluster)),perplexity = 200)
plot(tsne_out$Y, col = cluster_result)
legend(15,20,1:n_cluster,col = 1:n_cluster,pch = 1,pt.lwd = 4)

# Visualize through PCA
library(MASS)
library(FactoMineR)
bgg_pca <- PCA(scale(boardgame_cluster),ncp = 6,graph = FALSE)
#plot(bgg_pca,choix = "var")
#plot(bgg_pca$ind$coord)
#legend(20,20,1:n_cluster,col = 1:n_cluster,pch = 1,pt.lwd = 4)

plot(bgg_pca,axes = c(1,2),habillage = "ind",col.hab = cluster_result,label = "none")
legend(10,10,1:n_cluster,col = 1:n_cluster,pch = 1,pt.lwd = 4)
#========================================================
#========================================================
boardgame_cluster_all <- cbind(names = boardgame$names,boardgame_cluster,cluster = cluster_result)
boardgame_cluster_all %>% group_by(cluster) %>% summarise(n=n())

# major types (mechanic and category) of each cluster
cluster_type <- matrix(0,10,n_cluster)
for(i in 1:n_cluster){
  cluster_type[,i] <- names(sort(apply(boardgame_cluster_all[boardgame_cluster_all$cluster==i,-c(1,138)],2,sum),decreasing = TRUE)[1:10])
}

#=========================================================================
# Word Cloud and Frequency Plot
#=========================================================================
word_freq <- c()
for(i in 1:n_cluster){
  word_freq <- cbind(word_freq,apply(boardgame_cluster_all[boardgame_cluster_all$cluster==i,-c(1,138)],2,sum))
}

i = 1
d <- data.frame(word=names(sort(word_freq[,i],decreasing = T)),freq = sort(word_freq[,i],decreasing = T))
set.seed(1234)
if(d$freq[1]>3*d$freq[2]){
  size <- 0.1
} else{size <- 0.5}
wordcloud2(d, size = 0.8, fontWeight = "bold", color = "random-light",backgroundColor = "grey")
letterCloud(as.data.frame(d),word = "R",wordSize = 2)


size = 8
t = 0
while(is.null(t)!=T){
  t <- tryCatch(expr = {wordcloud(words = d$word,freq = d$freq,max.words = 100, scale = c(size,0.2),random.order = F,ordered.colors = T,colors = color,rot.per = 0.1)}, 
                warning = function(w) w
  )
  size = size/2
}

ggplot(data = d[1:10,],aes(x = reorder(word,-freq),y = freq)) + 
  geom_bar(stat = "identity", fill = "steelblue") +
  xlab("Game Type")+ ylab("Frequency") +
  ggtitle(paste("Top 10 Game Types of Cluster ",i))+
  theme_classic() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(size=24, face="bold.italic",hjust = 0.5),
    axis.title.x = element_text(size=14, face="bold"),
    axis.title.y = element_text(size=14, face="bold")
  )

ypos <- par()$usr[3] - 0.1*(par()$usr[4] - par()$usr[3])
b <- barplot(d[1:10,]$freq,axisnames = T)
axis(1,at = b,labels = F)
text(x = b, y = ypos,labels = d[1:10,]$word, srt = 45, xpd = T, adj = 1)




#=========================================================================
# Similarity
#=========================================================================

similarity_perc <- function(x,y){
  x1 <- boardgame_cluster_all[boardgame_cluster_all$names==x, -c(1,138)]
  y1 <- boardgame_cluster_all[boardgame_cluster_all$names==y, -c(1,138)]
  clusterx <- boardgame_cluster_all[boardgame_cluster_all$names==x, 138]
  clustery <- boardgame_cluster_all[boardgame_cluster_all$names==y, 138]
  perc <- (1 - sum((x1-y1)^2)/136)*100
  cat(paste("Cluster of ",x,"is ",clusterx,"\n"))
  cat(paste("Cluster of ",y,"is ",clustery,"\n"))
  cat(paste("similarity: ",perc,"%"))
}

game1 <- sample(boardgame_cluster_all$names,1)
game2 <- sample(boardgame_cluster_all$names,1)
similarity_perc(game1,game2)
similarity_perc("Agricola","Puerto Rico")
similarity_perc("Agricola","7 Wonders Duel")




#
boardgame_cluster_year <- cbind(boardgame_cluster_all,year = boardgame$year)
dim(boardgame_cluster_year)
years <- sort(unique(boardgame_cluster_year$year))
type_year <- c()

for(i in 1:length(years)){
  type_year <- cbind(type_year,colSums(boardgame_cluster_year[boardgame_cluster_year$year==years[i],2:137]))
  colnames(type_year)[i] <- as.character(years[i])
}

plot(x = years[60:104], y = type_year[3,60:104],type = "l")
rownames(type_year)




#
# related function ----
related = function(x){
  no_cluster = bg_clust[which(bg_clust$names == x), "cluster"]
  return(bg_clust[which(bg_clust$cluster == no_cluster),"names"])
}
related("Agricola")

# distance function ----
similar = function(x,n){
  temp = bg_clust[which(bg_clust$names == x),]
  dist = apply(bg_clust[which(bg_clust$cluster == temp$cluster),2:137], 1, 
               function(xx) sum((temp[2:137] - xx)^2))
  return(bg_clust[head(names(sort(dist)[-1]),n),1])
}
similar("Agricola",10)




