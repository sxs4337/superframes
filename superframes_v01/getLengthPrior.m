function [probability,bestLength] = getLengthPrior(segment_length,lognormal_params)
global lognormal_pdf
%getLengthPrior returns the probability of a certain SF length
     if exist('lognormal_params','var') % create a new probability density function
        lognormal_pdf=makedist('lognormal','mu',lognormal_params.mu,'sigma',lognormal_params.sigma);  
     end
     if segment_length>=0 % return the probability
        probability=pdf(lognormal_pdf,segment_length);
        bestLength=0;
     else % return the length with the highest probability
        shot_length=0.1:0.025:25;
        [~,bestIdx]=max(pdf(lognormal_pdf,shot_length));
        bestLength=shot_length(bestIdx);
        probability=0;
     end
end
