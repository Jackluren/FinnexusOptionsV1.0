pragma solidity ^0.5.1;
import "./OptionsOccupiedCal.sol";
/**
 * @title Options net worth calculation contract for finnexus proposal v2.
 * @dev A Smart-contract for net worth calculation.
 *
 */
contract OptionsNetWorthCal is OptionsOccupiedCal {
    /**
     * @dev retrieve all information for net worth calculation. 
     * @param whiteList collateral address whitelist.
     */ 
    function getNetWrothCalInfo(address[] memory whiteList)public view returns(uint256,int256[] memory){
        uint256 len = whiteList.length;
        int256[] memory latestNetWorth = new int256[](len);
            for (uint256 i = 0;i<len;i++){
            latestNetWorth[i] = optionsLatestNetWorth[whiteList[i]];
        }
        return ( netWorthirstOption,latestNetWorth);
    }
    /**
     * @dev retrieve latest options net worth which paid in settlement coin. 
     * @param settlement settlement coin address.
     */ 
    function getNetWrothLatestWorth(address settlement)public view returns(int256){
        return optionsLatestNetWorth[settlement];
    }
    /**
     * @dev set latest options net worth balance, only manager contract can modify database.
     * @param newFirstOption new first valid option position.
     * @param latestNetWorth latest options net worth.
     * @param whiteList eligible collateral address white list.
     */ 
    function setSharedState(uint256 newFirstOption,int256[] memory latestNetWorth,address[] memory whiteList) public onlyManager{
        require(newFirstOption <= allOptions.length, "newFirstOption calculate Error");
        if (newFirstOption >  netWorthirstOption){
             netWorthirstOption = newFirstOption;
        }
        uint256 len = whiteList.length;
        for (uint256 i = 0;i<len;i++){
            require(latestNetWorth[i]>=-1e40 && latestNetWorth[i]<=1e40,"latestNetWorth calculate error");
            optionsLatestNetWorth[whiteList[i]] += latestNetWorth[i];
        }
    }
    /**
     * @dev calculate options time shared value,from begin to end in the alloptionsList.
     * @param lastOption the last option position.
     * @param begin the begin options position.
     * @param end the end options position.
     * @param whiteList eligible collateral address white list.
     */
    function calRangeSharedPayment(uint256 lastOption,uint256 begin,uint256 end,address[] memory whiteList)
            public view returns(int256[] memory,uint256[] memory,uint256){
        if (begin>=lastOption || end <  netWorthirstOption){
            return(new int256[](whiteList.length),new uint256[](whiteList.length),0);
        }
        if (end>lastOption) {
            end = lastOption;
        }
        (uint256[] memory sharedBalances,uint256 _firstOption) = _calculateSharedPayment(begin,end,whiteList);
        if (begin < _firstOption){
            int256[] memory newNetworth = calculateExpiredPayment(begin,_firstOption,whiteList);
            return (newNetworth,sharedBalances,_firstOption);
        }
        
        return (new int256[](whiteList.length),sharedBalances,_firstOption);
    }
    /**
     * @dev subfunction, calculate options time shared value,from begin to end in the alloptionsList.
     * @param begin the begin options position.
     * @param end the end options position.
     * @param whiteList eligible collateral address white list.
     */
    function _calculateSharedPayment(uint256 begin,uint256 end,address[] memory whiteList)
            internal view returns(uint256[] memory,uint256){
        uint256[] memory totalSharedPayment = new uint256[](whiteList.length);
        uint256 newFirstOption;
        (begin,newFirstOption) = getFirstOption(begin, netWorthirstOption,end); 
        for (;begin<end;begin++){
            OptionsInfo storage info = allOptions[begin];
            OptionsInfoEx storage optionEx = optionExtraMap[begin];
            uint256 timeValue = _calculateCurrentPrice(optionEx.underlyingPrice,info.strikePrice,info.expiration,
                optionEx.ivNumerator,optionEx.ivDenominator,info.optType);
            if (timeValue<optionEx.fullPrice){
                timeValue = optionEx.fullPrice - timeValue;
                uint256 index = whiteListAddress._getEligibleIndexAddress(whiteList,optionEx.settlement);
                timeValue = optionEx.tokenTimePrice*timeValue*info.amount/calDecimals;
                require(timeValue<=1e40,"option time shared value calculate error");
                totalSharedPayment[index] = totalSharedPayment[index]+timeValue;
            }
        }
        return (totalSharedPayment,newFirstOption);
    }
    /**
     * @dev subfunction, calculate expired options shared value,from begin to end in the alloptionsList.
     * @param begin the begin options position.
     * @param end the end options position.
     * @param whiteList eligible collateral address white list.
     */
    function calculateExpiredPayment(uint256 begin,uint256 end,address[] memory whiteList)internal view returns(int256[] memory){
        int256[] memory totalExpiredPayment = new int256[](whiteList.length);
        for (;begin<end;begin++){
            OptionsInfo storage info = allOptions[begin];
            if (info.amount>0){
                OptionsInfoEx storage optionEx = optionExtraMap[begin];
                uint256 index = whiteListAddress._getEligibleIndexAddress(whiteList,optionEx.settlement);
                uint256 timeValue = optionEx.fullPrice*optionEx.tokenTimePrice*info.amount/calDecimals;
                require(timeValue<=1e40,"option time shared value calculate error");
                totalExpiredPayment[index] = totalExpiredPayment[index]+int256(timeValue);
            }
        }
        return totalExpiredPayment;
    }
    /**
     * @dev calculate options payback fall value,from begin to end in the alloptionsList.
     * @param lastOption the last option position.
     * @param begin the begin options position.
     * @param end the end options position.
     * @param whiteList eligible collateral address white list.
     */
    function calculatePhaseOptionsFall(uint256 lastOption,uint256 begin,uint256 end,address[] memory whiteList) public view returns(int256[] memory){
        if (begin>=lastOption || end <  netWorthirstOption){
            return new int256[](whiteList.length);
        }
        if (end>lastOption) {
            end = lastOption;
        }
        if (begin <=  netWorthirstOption) {
            begin =  netWorthirstOption;
        }
        uint256[] memory prices = getUnderlyingPrices();
        int256[] memory OptionsFallBalances = _calRangeOptionsFall(begin,end,whiteList,prices);
        uint256 whiteListLen = whiteList.length;
        for (uint256 index = 0;index<whiteListLen;index++){
            OptionsFallBalances[index] = OptionsFallBalances[index]/(int256(_oracle.getPrice(whiteList[index])));
        }
        return OptionsFallBalances;
    }
    /**
     * @dev subfunction, calculate options payback fall value,from begin to lastOption in the alloptionsList.
     * @param begin the begin option position.
     * @param lastOption the last option position.
     * @param whiteList eligible collateral address white list.
     * @param prices eligible underlying price list.
     */
    function _calRangeOptionsFall(uint256 begin,uint256 lastOption,address[] memory whiteList,uint256[] memory prices)
                 internal view returns(int256[] memory){
        int256[] memory OptionsFallBalances = new int256[](whiteList.length);
        for (;begin<lastOption;begin++){
            OptionsInfo storage info = allOptions[begin];
            if(info.expiration<now || info.amount == 0){
                continue;
            }
            uint256 index = _getEligibleUnderlyingIndex(info.underlying);
            int256 curValue = _calCurtimeCallateralFall(info,info.amount,prices[index]);
            if (curValue != 0){
                OptionsInfoEx storage optionEx = optionExtraMap[begin];
                index = whiteListAddress._getEligibleIndexAddress(whiteList,optionEx.settlement);
                OptionsFallBalances[index] = OptionsFallBalances[index]-curValue;
            }
        }
        return OptionsFallBalances;
    }
    /**
     * @dev subfunction, calculate option payback fall value.
     * @param info the option information.
     * @param amount the option amount to calculate.
     * @param curPrice current underlying price.
     */
    function _calCurtimeCallateralFall(OptionsInfo memory info,uint256 amount,uint256 curPrice) internal view returns(int256){
        if (info.expiration<=now || amount == 0){
            return 0;
        }
        uint256 newFall = _getOptionsPayback(info.optType,info.strikePrice,curPrice)*amount;
        OptionsInfoEx storage optionEx = optionExtraMap[info.optionID-1];
        uint256 OriginFall = _getOptionsPayback(info.optType,info.strikePrice,optionEx.underlyingPrice)*amount;
        int256 curValue = int256(newFall) - int256(OriginFall);
        require(curValue>=-1e40 && curValue<=1e40,"options fall calculate error");
        return curValue;
    }
    /*
    function _addNewOptionsNetworth(OptionsInfo memory info)  internal {
        OptionsInfoEx storage infoEx =  optionExtraMap[info.optionID-1];
        uint256 price = _oracle.getPrice(infoEx.settlement);
        uint256 curValue = _calCurtimeCallateralFall(info,info.amount,infoEx.underlyingPrice)/price;
        optionsLatestNetWorth[infoEx.settlement] = optionsLatestNetWorth[infoEx.settlement].sub(int256(curValue));
    }
    */
    /**
     * @dev set burn option net worth change.
     * @param info the option information.
     * @param amount the option amount to calculate.
     * @param underlyingPrice underlying price when option is created.
     * @param currentPrice current underlying price.
     */
    function _burnOptionsNetworth(OptionsInfo memory info,uint256 amount,uint256 underlyingPrice,uint256 currentPrice) internal {
        int256 curValue = _calCurtimeCallateralFall(info,amount,underlyingPrice);
        OptionsInfoEx storage optionEx = optionExtraMap[info.optionID-1];
        uint256 timeWorth = optionEx.fullPrice>currentPrice ? optionEx.fullPrice-currentPrice : 0;
        timeWorth = optionEx.tokenTimePrice*timeWorth*amount/calDecimals;
        curValue = curValue / int256(_oracle.getPrice(optionEx.settlement));
        int256 value = curValue - int256(timeWorth);
        optionsLatestNetWorth[optionEx.settlement] = optionsLatestNetWorth[optionEx.settlement]+value;
    }
    /**
     * @dev An anxiliary function, calculate time shared current option price.
     * @param curprice underlying price when option is created.
     * @param strikePrice the option strikePrice.
     * @param expiration option time expiration time left, equal option.expiration - now.
     * @param ivNumerator Implied valotility numerator when option is created.
     * @param ivDenominator Implied valotility denominator when option is created.
     */
    function _calculateCurrentPrice(uint256 curprice,uint256 strikePrice,uint256 expiration,uint256 ivNumerator,uint256 ivDenominator,uint8 optType)internal view returns (uint256){
        if (expiration > now){
            return _optionsPrice.getOptionsPrice_iv(curprice,strikePrice,expiration-now,ivNumerator,
                ivDenominator,optType);
        }
        return 0;
    }
}