function p = temperatureScores(p,T)
%TEMPERATURESCORES Apply fitted positive temperature to log probabilities.
validateattributes(T,{'numeric'},{'real','finite','scalar','positive'});
logits = log(max(double(p),1e-12))/T;
logits = logits-max(logits,[],2); p = exp(logits); p = p./sum(p,2);
end
