classdef growingInterpolation < base & event.source
    %% GROWINGINTERPOLATION
    % This class can be used if a complex computationally intensice
    % function is used within any model. The primary example for this is
    % the calculation performed within the CHX model. This class can be
    % used to dynamically store the corresponding output values of the
    % function for the inputs. Instead of the function itself, the function
    % "calculateOutputs" of this class should then be used. The original
    % function is stored within this class as handle in the property
    % "hFunction". For each new query it checks whether an existing
    % previously calculated data point is close enough to be reused instead
    % of recalculating the function. The limits defined for the reuse can
    % be defined by the user either as percentual limits or absolute limits
    % using the function "adjustLimits".
    % The only currently implemented interpolation is a nearest neighbor
    % interpolation. The closest matching stored data point for this is
    % found by calculated the residual sum of squares (RSS) between the
    % provided inputs and the stored inputs. Beforehand the user defined
    % limits are checked to ensure a valid point is stored in the class.
    
    properties (SetAccess = public, GetAccess = public)
        % The identifier for this interpolation object
        sName;
        
        % The parent object to which this interpolation is attached (e.g. a CHX)
        oParent;
        
        % Handle of the function which is interpolated. Used to calculate
        % new points which are not yet stored in the interpolation. The
        % function must be written to use a vector as input and provide a
        % vector as output. The number of elements in the vectors are not
        % limited
        hFunction;
        
        % Array the same length as the input vector. (e.g. if the input
        % vector has 16 elements, then this vector should also have 16
        % elements). Each entry in the vector represents the PERCENTUAL
        % limit for when an existing point stored in the interpolation will
        % be deemed valid to be used instead of the actual function. For
        % example, if the first input is the air temperature of a CHX and
        % the corresponding entry of arRelativeInputDeviationLimits is
        % 0.001 then a change of 0.1% will result in a recalculation. For a
        % temperature of 293 K this corresponds to 0.293 K.
        arRelativeInputDeviationLimits;
        
        % Array the same length as the input vector. (e.g. if the input
        % vector has 16 elements, then this vector should also have 16
        % elements). Each entry in the vector represents the ABSOLUTE
        % limit for when an existing point stored in the interpolation will
        % be deemed valid to be used instead of the actual function. E.g.
        % if the limit for the air temperature of a CHX is set to 1, then a
        % new point will be calculated if the air temperature differs by at
        % least 1 K
        afAbsoluteInputDeviationLimits;
        
        % Integer which stores the number of input elements (the length of
        % the input vector) for the function stored hFunction
        iInputs;
        
        % Integer which stores the number of output elements (the length of
        % the output vector) for the function stored hFunction
        iOutputs;
        
        % Mean value of all stored input values element wise.
        mfMeanInputData;
        
        % Matrix which stores the input data for all previously calculated
        % data points. This is used to both decide which point fits the
        % current data and to decide if a new point should be calculated.
        % Each row is a new point which was calculated previously.
        mfStoredInputData;
        
        % Matrix which stores to corresponding outputs to the values stored
        % in mfStoredInputData. The outputs stored in each row of
        % mfStoredOutputData correspond to the same row in mfStoredInputData
        mfStoredOutputData;
    end
    methods
        function this = growingInterpolation(oParent, sName, hFunction, arRelativeInputDeviationLimits, afAbsoluteInputDeviationLimits)
            % class definition for a growingInterpolation class. The
            % required inputs are:
            % oParent:      The parent object for this interpolation, e.g. 
            %               the CHX
            % hFunction:    Handle to the function which is interpolated.
            %               The function must use a vector of arbitrary
            %               length as input and provide another vector of
            %               arbitrary length as output!
            % arRelativeInputDeviationLimits: Array the same length as the
            %               input vector. (e.g. if the input vector has 16
            %               elements, then this vector should also have 16
            %               elements). Each entry in the vector represents
            %               the PERCENTUAL limit for when an existing point
            %               stored in the interpolation will be deemed
            %               valid to be used instead of the actual
            %               function.
            %
            % Optional Inputs:
            % afAbsoluteInputDeviationLimits: Array the same length as the
            %               input vector. (e.g. if the input vector has 16
            %               elements, then this vector should also have 16
            %               elements). Each entry in the vector represents
            %               the ABSOLUTE limit for when an existing point
            %               stored in the interpolation will be deemed
            %               valid to be used instead of the actual
            %               function. 
            this.oParent    = oParent;
            this.sName      = sName;
            this.hFunction  = hFunction;
            
            this.arRelativeInputDeviationLimits = arRelativeInputDeviationLimits;
                
            if nargin > 4
                this.afAbsoluteInputDeviationLimits = afAbsoluteInputDeviationLimits;
            end
 
        end
        function [mfClosestOutputs, bFoundMatch, fRSS] = calculateOutputs(this, mfInputs, bForceNewCalculation)
            % This function is then called instead of the function stored
            % in the "hFunction" property. The stored function is only
            % executed in case no valid point is found within this
            % interpolation. The inputs for this function are:
            % mfInputs: The vector containing the current inputs for which
            %           the outputs shall be calculated. Formatting depends
            %           on the interpolated function and is therefore user
            %           defined!
            %
            % Optional Input:
            % bForceNewCalculation: Boolean which can be called if a new
            %           calculation of the stored function should be forced
            %           (which will also create a new stored data point
            %           within this interpolation)
            %
            % Outputs are:
            % mfClosestOutputs: The output vector from the stored function,
            %           either based on the stored values from the
            %           interpolation or from the calculation of the
            %           function. Format depends on the stored function and
            %           is therefore user defined!
            % bFoundMatch: Boolean which informs the user whether a valid
            %           match within the available data was found
            % fRSS:     Residual Sum of Squares for the selected
            %           interpolation point. It can be used as a measure of how well
            %           the used data point fits the inputs
            
            % If not specifically requested a new calculation is not forced
            if nargin < 3
                bForceNewCalculation = false;
            end
            
            % Use the "checkMatch" function to check whether any stored
            % point matches the limits defined by the properties
            % "arRelativeInputDeviationLimits" and "afAbsoluteInputDeviationLimits"
            bFoundMatch = this.checkMatch(mfInputs);
            
            if bFoundMatch && ~bForceNewCalculation
            % If a valid match was found (and no new calculation is forced)
            % the closest matching datapoint from the stored data is used
                [mfClosestOutputs, fRSS] = this.findClosestMatch(mfInputs);
                
            else
            % If no match is found or a new calculation is force, the
            % stored function handle is used to calculate the outputs. The
            % RSS is 0 for this case, as the values are calculates exactly
            % for the desired inputs.
                fRSS = 0;
                
                mfClosestOutputs = this.hFunction(mfInputs);
                
                % Add the newly calculated data point to the points stored
                % within this interpolation object
                this.addDataPoint(mfInputs, mfClosestOutputs);
            end
        end
        function adjustLimits(this, arRelativeInputDeviationLimits, afAbsoluteInputDeviationLimits)
            % The adjustLimits function can be used to change the defined
            % limits for when a point stored in the interpolation object is
            % considered valid and no recalculation of the stored function
            % is required. The inputs are:
            % arRelativeInputDeviationLimits: Array the same length as the
            %               input vector. (e.g. if the input vector has 16
            %               elements, then this vector should also have 16
            %               elements). Each entry in the vector represents
            %               the PERCENTUAL limit for when an existing point
            %               stored in the interpolation will be deemed
            %               valid to be used instead of the actual
            %               function.
            %
            % Optional Inputs:
            % afAbsoluteInputDeviationLimits: Array the same length as the
            %               input vector. (e.g. if the input vector has 16
            %               elements, then this vector should also have 16
            %               elements). Each entry in the vector represents
            %               the ABSOLUTE limit for when an existing point
            %               stored in the interpolation will be deemed
            %               valid to be used instead of the actual
            %               function.
            
            this.arRelativeInputDeviationLimits = arRelativeInputDeviationLimits;
                
            if nargin > 4
                this.afAbsoluteInputDeviationLimits = afAbsoluteInputDeviationLimits;
            end
        end
        
        function loadStoredData(this, tData)
            % The loadStoredData function can be used to reload
            % interpolation data points from a file (tData). The tData file
            % can be created with the "storeData" function of this class.
            % The Inputs are:
            % tData:    A struct with the fields "Input" and "Output"
            %           containing previously calculated matrices for the
            %           input data and the corresponding output data. Note
            %           that if "wrong" data is loaded, e.g. data for the
            %           wrong CHX, this can result in unphysical behavior!
            
            % Load the stored data into the properties:
            this.mfStoredInputData  = tData.Input;
            this.mfStoredOutputData = tData.Output;
            
            % Check the in- and output sizes and store the corresponding
            % properties
            aiInputSize             = size(this.mfStoredInputData);
            aiOutputSize            = size(this.mfStoredOutputData);

            this.iInputs            = aiInputSize(2);
            this.iOutputs           = aiOutputSize(2);
            
            % Calculate the mean values over the input data:
            this.mfMeanInputData	= mean(this.mfStoredInputData, 1);
            
        end
        function storeData(this, sFileName)
            % This function can be used to store the interpolation data to
            % the harddrive to be loaded later on using the "loadStoredData"
            % function. The only input is optional:
            % sFileName: Name of the file to which the data should be
            %            written
            tData.Input     = this.mfStoredInputData;
            tData.Output    = this.mfStoredOutputData;
            
            if nargin < 2
                sFileName = this.sName;
            end
            save(sFileName, tData);
        end
    end
    methods (Access = protected)
        function addDataPoint(this, mfInputs, mfOutputs)
            % The addDataPoint function is used to add a newly calculated
            % data point to the stored interpolation data within this
            % object. The inputs are:
            % mfInputs: The input vector for which the new outputs were
            %           calculated
            % mfOutputs: The newly calculated output vector
            
            if isempty(this.iInputs)
                % Check the in- and output vector size only if the
                % properties are not yet defined.
                this.iInputs    = length(mfInputs);
                this.iOutputs   = length(mfOutputs);
            end
            this.mfStoredInputData(end+1, :)    = mfInputs;
            this.mfStoredOutputData(end+1, :)   = mfOutputs;
            % Updated the stored mean input data values:
            this.mfMeanInputData                = mean(this.mfStoredInputData, 1);
        end
        
        function bMatch = checkMatch(this, mfInputs)
            % The checkMatch function is used to decide whether any stored
            % data point is close enough to the provided input vector to be
            % used instead of a recalculation of hFunction.
            
            % First check if any data is currently stored at all:
            if ~isempty(this.mfStoredInputData)
                % If data is stored, calculate the absolute deviations
                % between all stored data points and the provided inputs:
                mfAbsoluteDeviation = abs(this.mfStoredInputData - mfInputs);

                % Then only if the absolute deviation property is not
                % empty, check if any point is below these limits for all
                % inputs
                abAbsolute = true;
                if ~isempty(this.afAbsoluteInputDeviationLimits)
                    abAbsolute = mfAbsoluteDeviation < this.afAbsoluteInputDeviationLimits;
                end
                
                % For the relative limits, first the percentual change is
                % calculated and then we check whether any stored point is
                % below the limits for all inputs.
                if ~isempty(this.arRelativeInputDeviationLimits)
                    abRelative = (mfAbsoluteDeviation ./ abs(mfInputs)) < this.arRelativeInputDeviationLimits;
                end

                % In case at least one point matches all criteria we found
                % a match, otherwise no valid match was found in the stored
                % data
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
            % The findClosestMatch function is used to select the most
            % suitable data point to be used for the provided inputs from
            % the stored data point. For this purpose the residual sum of
            % squares (RSS) is calculated and the point with the smallest
            % RSS is used.
            mfRSS = sum(((this.mfStoredInputData - mfInputs) ./ this.mfMeanInputData).^2, 2);
            abClosestValue = min(mfRSS) == mfRSS;
            aiClosestMatch = find(abClosestValue);
            
            % Just in case two or more stored points have the exact same
            % RSS value, we use the mean between these points:
            mfClosestOutputs = mean(this.mfStoredOutputData(aiClosestMatch,:),1);
            fRSS = mean(mfRSS(aiClosestMatch));
        end
    end
end