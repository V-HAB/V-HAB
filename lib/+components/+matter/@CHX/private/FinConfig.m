function [tFinOutput] = FinConfig(l, k, tFinOutput, tFinInput)
% This function calculate the additional thermal resistance of a fin in a
% numeric cell dependent on the position of the cell and the fin. Detailes
% explanation in MA2018-10 by Fabian Lübbetr Appendix B
%% Inputs

fFinBroadness_1       = tFinInput.fFinBroadness_1;
fFinBroadness_2       = tFinInput.fFinBroadness_2;
fIncrementalLenght    = tFinInput.fIncrementalLenght;
fIncrementalBroadness = tFinInput.fIncrementalBroadness;
iFinCounterAir        = tFinOutput.iFinCounterAir;
iFinCounterCoolant    = tFinOutput.iFinCounterCoolant;
iCellCounterAir       = tFinOutput.iCellCounterAir;
iCellCounterCoolant   = tFinOutput.iCellCounterCoolant;
fOverhangAir          = tFinOutput.fOverhangAir;
fOverhangCoolant      = tFinOutput.fOverhangCoolant;
fFinOverhangAir       = tFinOutput.fFinOverhangAir;
fFinOverhangCoolant   = tFinOutput.fFinOverhangCoolant;

%% Air loop 
% Calculation for the fins inside the air channel 
    if fIncrementalLenght <= fFinBroadness_1
        %check if cell length is a multiple of fin
        %broadness
        fCellPositionAir = fFinBroadness_1 - (iCellCounterAir*fIncrementalLenght + fOverhangAir);
        if fCellPositionAir >= 0
            iFinStateAir = mod(iFinCounterAir,2);
            fFinFactorAir = 1;
            iCellCounterAir = iCellCounterAir + 1;
        else
            iFinStateAir = mod(iFinCounterAir,2);
            
            % Overhange = part of the cell that goes in the are of the next
            % fin 
            fOverhangAir = (iCellCounterAir*fIncrementalLenght + fOverhangAir) - fFinBroadness_1;

            % Leftover = part of the cell that
            % remain in the are of the first fin 
            fLeftOverAir = fIncrementalLenght - fOverhangAir;

            switch iFinStateAir
                case 1
                    fFinFactorAir = fLeftOverAir/fFinBroadness_1;
                case 0
                    fFinFactorAir = fOverhangAir/fFinBroadness_1;
            end
            iFinCounterAir = iFinCounterAir + 1;
            iCellCounterAir = 1;
        end
    else
        while fFinBroadness_1*iFinCounterAir - fIncrementalLenght * l < 0
            iFinCounterAir = iFinCounterAir+1;
        end
        iFinStateAir = mod(iFinCounterAir,2);
        fFinOverhangAir = fFinBroadness_1*iFinCounterAir - (fIncrementalLenght * l + fFinOverhangAir);
        if fFinOverhangAir == 0
            switch iFinStateAir
                case 0
                    fFinFactorAir = 0.5;
                case 1
                    fFinFactorAir = (((iFinCounterAir-1)/2)+1)/(iFinCounterAir);
            end
        else
            fFinLeftoverAir = fFinBroadness_1 - fFinOverhangAir;


            switch iFinStateAir
                case 0
                    fFinFactorAir = ((((iFinCounterAir-1)-1)/2)+1)/(iFinCounterAir-1)-(1/iFinCounterAir)*fFinLeftoverAir;
                case 1
                    fFinFactorAir = (((iFinCounterAir-1)/2)+1)/(iFinCounterAir)-(1/iFinCounterAir)*fFinLeftoverAir;
            end
        end

    end

    %% Coolant loop
% Calculation for the fins inside the coolant channel 
    if fIncrementalBroadness <= fFinBroadness_2
        %check if cell length is a multiple of fin
        %broadness
        fCellPositionCoolant = fFinBroadness_2 - (iCellCounterCoolant*fIncrementalBroadness + fOverhangCoolant);
        if fCellPositionCoolant >= 0
            iFinStateCoolant = mod(iFinCounterCoolant,2);
            fFinFactorCoolant = 1;
            iCellCounterCoolant = iCellCounterCoolant + 1;
        else
            iFinStateCoolant = mod(iFinCounterCoolant,2);
            fOverhangCoolant = (iCellCounterCoolant*fIncrementalBroadness + fOverhangCoolant)- fFinBroadness_2;

            % Leftover = part of the cell that
            % remain in the first fin area
            fLeftOverCoolant = fIncrementalBroadness - fOverhangCoolant;

            switch iFinStateCoolant
                case 1
                    fFinFactorCoolant = fLeftOverCoolant/fFinBroadness_2;
                case 0
                    fFinFactorCoolant = fOverhangCoolant/fFinBroadness_2;
            end
            iFinCounterCoolant = iFinCounterCoolant + 1;
            iCellCounterCoolant = 1;
        end
    else
        while fFinBroadness_2*iFinCounterCoolant - fIncrementalBroadness * k < 0
            iFinCounterCoolant = iFinCounterCoolant+1;
        end
        iFinStateCoolant = mod(iFinCounterCoolant,2);
        fFinOverhangCoolant = fFinBroadness_2*iFinCounterCoolant - (fIncrementalBroadness * k + fFinOverhangCoolant);
        if fFinOverhangCoolant == 0
            switch iFinStateCoolant
                case 0
                    fFinFactorCoolant = 0.5;
                case 1
                    fFinFactorCoolant = (((iFinCounterCoolant-1)/2)+1)/(iFinCounterCoolant);
            end
        else
            fFinLeftoverCoolant = fFinBroadness_2 - fFinOverhangCoolant;


            switch iFinStateCoolant
                case 0
                    fFinFactorCoolant = ((((iFinCounterCoolant-1)-1)/2)+1)/(iFinCounterCoolant-1) - (1/iFinCounterCoolant)*fFinLeftoverCoolant;
                case 1
                    fFinFactorCoolant = (((iFinCounterCoolant-1)/2)+1)/(iFinCounterCoolant) - (1/iFinCounterCoolant)*fFinLeftoverCoolant;
            end
        end

    end
%% Outputs
tFinOutput.iFinCounterAir      = iFinCounterAir;
tFinOutput.iFinCounterCoolant  = iFinCounterCoolant;
tFinOutput.iCellCounterAir     = iCellCounterAir;
tFinOutput.iCellCounterCoolant = iCellCounterCoolant;
tFinOutput.fOverhangAir        = fOverhangAir;
tFinOutput.fOverhangCoolant    = fOverhangCoolant;
tFinOutput.fFinFactorAir       = fFinFactorAir;
tFinOutput.fFinFactorCoolant   = fFinFactorCoolant;
tFinOutput.iFinStateAir        = iFinStateAir;
tFinOutput.iFinStateCoolant    = iFinStateCoolant;
tFinOutput.fOverhangAir        = fOverhangAir;
tFinOutput.fOverhangCoolant    = fOverhangCoolant;
tFinOutput.iCellCounterAir     = iCellCounterAir;
tFinOutput.iCellCounterCoolant = iCellCounterCoolant;

% fprintf('iFinStateAir = %i, iFinStateCoolant = %i fFinFactorAir = %f fFinFactorCoolant = %f\n', iFinStateAir, iFinStateCoolant, fFinFactorAir, fFinFactorCoolant)
% fprintf('fOverhangAir = %f', fOverhangAir)
end

