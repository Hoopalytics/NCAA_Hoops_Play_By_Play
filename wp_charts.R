source("NCAA_Hoops_PBP_Scraper.R")
dict <- read.csv("ESPN_NCAA_Dict.csv", as.is = T)
#games <- read.csv("pbp_2016_17/all_games.csv", as.is = T)
wp_hoops <- readRDS("wp_hoops.rds")
y <- read.csv("https://raw.githubusercontent.com/lbenz730/NCAA_Hoops/master/2.0_Files/Results/2017-18/NCAA_Hoops_Results_11_19_2017.csv", 
              as.is = T)
x <- read.csv("https://raw.githubusercontent.com/lbenz730/NCAA_Hoops/master/2.0_Files/Power_Rankings/Powerrankings.csv", 
              as.is = T)
z <- read.csv("pbp_2016_17/NCAA_Hoops_Results_6_29_2017.csv", as.is = T)
prior <- glm(wins ~ predscorediff, data = z, family = binomial)

secs_to_model <- function(sec, msec) {
  offset <- msec - 2400
  if(offset == 300 & sec > offset) {
    sec <- sec - offset
  }
  if(offset == 600) {
    if(sec > 600) {
      sec <- sec - offset
    }
    else if (sec < 600 & sec > 300) {
      sec <- sec - 300
    }
  }
  else if(offset == 900) {
    if(sec > 900) {
      sec <- sec - offset
    }
    else if (sec <= 900 & sec > 600) {
      sec <- sec - 600
    }
    else if (sec <= 600 & sec > 300) {
      sec <- sec - 300
    }
  }
  else if(offset == 1200) {
    if(sec > 1200) {
      sec <- sec - offset
    }
    else if (sec <= 1200 & sec > 900) {
      sec <- sec - 900
    }
    else if (sec <= 900 & sec > 600) {
      sec <- sec - 600
    }
    else if (sec <= 600 & sec > 300) {
      sec <- sec - 300
    }
  }
  
          
  if(sec <= 30) {
    m <- sec + 1
  }
  else if(sec > 30 & sec <= 60) {
    m <- 31 + floor((sec - 30)/2)
  }
  else if(sec > 60 & sec < 2700) {
    m <- 46 + floor((sec - 60)/10)
  }
  else{
    m <- 309
  }
  return(m)
}

get_line <- function(data) {
  away <- data$away[1]
  home <- data$home[1]
  
  ### Convert to NCAA Names
  away <- dict$NCAA[dict$ESPN_PBP == away]
  home <- dict$NCAA[dict$ESPN_PBP == home]
  
  ### Get Predicted Line
  if(length(home) == 0 | length(away) == 0) {
    return(NA)
  }
  game <- y %>% filter(team == home, opponent == away, location == "H")
  HCA <- 3.5
  if(nrow(game) == 0) {
    game <- y %>% filter(team == home, opponent == away, location == "N")
    HCA <- 0
    if(nrow(game) == 0) {
      return(0)
    }
  }
  line <- x$YUSAG_Coefficient[x$Team == home] - x$YUSAG_Coefficient[x$Team == away] + HCA
  return(line)
}

wp_chart <- function(gameID, home_col, away_col) {
  ### Scrape Data from ESPN
  data <- get_pbp_game(gameID)
  
  ### Cleaning
  data$scorediff <- data$home_score - data$away_score
  if(is.na(data$home_favored_by[1])) {
    data$home_favored_by <- get_line(data)
  }
  data$pre_game_prob <- predict(prior, newdata = data.frame(predscorediff = data$home_favored_by), 
                                type = "response")
  
  ### Compute Win Prob
  data$winprob <- NA
  msec <- max(data$secs_remaining)
  for(i in 1:nrow(data)) {
    m <- secs_to_model(data$secs_remaining[i], msec)
    model <- wp_hoops[[m]]$coefficients
    log_odds <- model[1] + data$scorediff[i]*model[2] + data$pre_game_prob[i]*model[3]
    odds <- exp(log_odds)
    data$winprob[i] <- odds/(1 + odds)
  }
  
  ### Plot Results
  data$secs_elapsed <- max(data$secs_remaining) - data$secs_remaining
  title <- paste("Win Probability Chart for", data$away[1], "vs.", data$home[1])
  plot(winprob ~ secs_elapsed, data = data, col = home_col, type = "l", lwd = 3, ylim = c(0,1),
       xlab = "Seconds Elapsed", ylab = "Win Probability", main = title)
  par(new = T)
  plot((1 - winprob) ~ secs_elapsed, data = data, col = away_col, type = "l", lwd = 3, ylim = c(0,1),
       xlab = "", ylab = "", main = "")
  abline(h = 0.5, lty = 2)
  if(data$winprob[1] < 0.85) {
    legend("topleft", col = c(home_col, away_col), legend = c(data$home[1], data$away[1]), lty = 1, 
           cex = 0.5)
  }
  else{
    legend("left", col = c(home_col, away_col), legend = c(data$home[1], data$away[1]), lty = 1, 
           cex = 0.5)
  }
}

### Usage
wp_chart(260600245, "maroon", "orange")
