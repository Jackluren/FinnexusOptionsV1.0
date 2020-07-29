pragma solidity ^0.4.26;
import "./Halt.sol";
import "./whiteList.sol";
    /**
     * @dev Implementation of a whitelist filters a eligible address.
     */
contract AddressWhiteList is Halt {

    uint256 constant allPermission = 0xffffffff;
    uint256 constant allowPayIn = 0x0001;
    uint256 constant allowRedeemOut = 0x0002;
    // The eligible adress list
    address[] public whiteList;
    mapping(address => uint256) addressPermission;
    /**
     * @dev Implementation of add an eligible address into the whitelist.
     * @param addAddress new eligible address.
     */
    function addWhiteList(address addAddress)public onlyOwner{
        whiteListAddress.addWhiteListAddress(whiteList,addAddress);
        addressPermission[addAddress] = allPermission;
    }
    function modifyPermission(address addAddress,uint256 permission)public onlyOwner{
        addressPermission[addAddress] = permission;
    }
    /**
     * @dev Implementation of revoke an invalid address from the whitelist.
     * @param removeAddress revoked address.
     */
    function removeWhiteList(address removeAddress)public onlyOwner returns (bool){
        return whiteListAddress.removeWhiteListAddress(whiteList,removeAddress);
    }
    /**
     * @dev Implementation of getting the eligible whitelist.
     */
    function getWhiteList()public view returns (address[]){
        return whiteList;
    }
    /**
     * @dev Implementation of testing whether the input address is eligible.
     * @param tmpAddress input address for testing.
     */    
    function isEligibleAddress(address tmpAddress) public view returns (bool){
        return whiteListAddress.isEligibleAddress(whiteList,tmpAddress);
    }
    function checkAddressPayIn(address tmpAddress) public view returns (bool){
        return isEligibleAddress(tmpAddress) && ((addressPermission[tmpAddress]&allowPayIn) == allowPayIn);
    }
    function checkAddressRedeemOut(address tmpAddress) public view returns (bool){
        return isEligibleAddress(tmpAddress) && ((addressPermission[tmpAddress]&allowRedeemOut) == allowRedeemOut);
    }
}