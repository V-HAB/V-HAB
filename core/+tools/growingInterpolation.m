classdef growingInterpolation < base & event.source
    properties (SetAccess = public, GetAccess = public)
        sName;
        oParent;
        hFunction;
        arRelativeInputDeviationLimits;
        afAbsoluteInputDeviationLimits;
        
        iInputs;
        iOutputs;
        mfMeanInputData;
        mfStoredInputData;
        mfStoredOutputData;
    end
    methods
        function this = growingInterpolation(oParent, sName, hFunction, arRelativeInputDeviationLimits, afAbsoluteInputDeviationLimits)
            
            this.oParent    = oParent;
            this.sName      = sName;
            this.hFunction  = hFunction;
            
            this.arRelativeInputDeviationLimits = arRelativeInputDeviationLimits;
                
            if nargin > 4
                this.afAbsoluteInputDeviationLimits = afAbsoluteInputDeviationLimits;
            end
 
        end
        function [mfClosestOutputs, bFoundMatch, fRSS] = calculateOutputs(this, mfInputs)
            % bFoundMatch = 0 means value was newly calculate as no available
            % data point matched the inputs
            % bFoundMatch = 1 means a value in the stored data was close
            % enough to be a match and was used for the outputs
            bFoundMatch = this.checkMatch(mfInputs);
            if bFoundMatch
                [mfClosestOutputs, fRSS] = this.findClosestMatch(mfInputs);
                
            else
                fRSS = 0;
                
                mfClosestOutputs = this.hFunction(mfInputs);
                
                this.addDataPoint(mfInputs, mfClosestOutputs);
            end
        end
    end
    methods (Access = protected)
        function addDataPoint(this, mfInputs, mfOutputs)
 
            if isempty(this.iInputs)
                this.iInputs    = length(mfInputs);
                this.iOutputs   = length(mfOutputs);
            end
            this.mfStoredInputData(end+1, :)    = mfInputs;
            this.mfStoredOutputData(end+1, :)   = mfOutputs;
            this.mfMeanInputData                = mean(this.mfStoredInputData, 1);
        end
        
        function bMatch = checkMatch(this, mfInputs)
            if ~isempty(this.mfStoredInputData)
                mfAbsoluteDeviation = abs(this.mfStoredInputData - mfInputs);

                abAbsolute = true;
                if ~isempty(this.afAbsoluteInputDeviationLimits)
                    abAbsolute = mfAbsoluteDeviation < this.afAbsoluteInputDeviationLimits;
                end
                if ~isempty(this.arRelativeInputDeviationLimits)
                    abRelative = (mfAbsoluteDeviation ./ abs(mfInputs)) < this.arRelativeInputDeviationLimits;
                end

                if any(all(abRelative,2)) && any(all(abAbsolute,2))
                    bMatch = true;
                else
                    bMatch = false;
                end
            else
                bMatch = false;
            end
        end
        
        function [mfClosestOutputs, fRSS] = findClosestMatch(this, mfInputs)
            
            mfDiff = sum(((this.mfStoredInputData - mfInputs) ./ this.mfMeanInputData).^2, 2);
            abClosestValue = min(mfDiff) == mfDiff;
            aiClosestMatch = find(abClosestValue);
            mfClosestOutputs = mean(this.mfStoredOutputData(aiClosestMatch,:),1);
            fRSS = mean(mfDiff(aiClosestMatch));
        end
    end
end