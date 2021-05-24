// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './IERC20.sol';
import './ERC721.sol';
import './Ownable.sol';

contract MetaXSeals is ERC721, Ownable {
    using SafeMath for uint256;
    uint public constant MAX_SEALS = 5001;
    bool public hasSaleStarted = false;
    
    string public METADATA_PROVENANCE_HASH = "";
    address public priceToken;
    address public burnAddress = address(0x000000000000000000000000000000000000dEaD);

    constructor(address tokenAddress) ERC721("MetaXSeals","MetaX")  {
        setBaseURI("https://fair.game/api/");
        feeReceiver = payable(msg.sender);
        priceToken = tokenAddress;
    } 
    
    function tokensOfOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }
    
    function calculatePrice() public view returns (uint256) {
        require(hasSaleStarted == true, "Sale hasn't started");
        require(totalSupply() < MAX_SEALS, "Sale has already ended");
        
        uint currentSupply = totalSupply(); 
        
        if (currentSupply == 5000) {
            return 20000000000000000000000;
        } else if (currentSupply >= 3000) {
            return 5000000000000000000000;
        } else if (currentSupply >= 2000) {
            return 4000000000000000000000;
        } else if (currentSupply >= 1000) {
            return 3000000000000000000000;
        }  else {
            return 2000000000000000000000;
        }
    }
    
    
   function summonSeal(uint256 maxSeals) public payable {
        require(totalSupply() < MAX_SEALS, "Sale has already ended");
        require(maxSeals > 0 && maxSeals <= 20, "You can craft minimum 1, maximum 20 seals");
        require(totalSupply().add(maxSeals) <= MAX_SEALS, "Exceeds MAX_SEALS");
        // require(msg.value >= calculatePrice().mul(maxSeals), "Ether value sent is below the price");
        IERC20(priceToken).transferFrom(msg.sender, address(this), calculatePrice().mul(maxSeals));

        for (uint i = 0; i < maxSeals; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }
    
    // ONLYOWNER FUNCTIONS
    
    function setProvenanceHash(string memory _hash) public onlyOwner {
        METADATA_PROVENANCE_HASH = _hash;
    }
    
    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }
    
    function startDrop() public onlyOwner {
        hasSaleStarted = true;
    }
    
    function pauseDrop() public onlyOwner {
        hasSaleStarted = false;
    }
    
    // MARKET
    function setTokenPrice(uint256 id, uint256 setPrice) public {
        require(msg.sender == ownerOf(id));
        Bazaar[id].price = setPrice;
        Bazaar[id].state = TokenState.ForSale;
        emit ForSale(id,setPrice);
    }
    
    function cancelTokenSale(uint256 id) public {
        require(msg.sender == ownerOf(id));
        delete Bazaar[id].price;
        Bazaar[id].state = TokenState.Neutral;
    }
    
    function buy(uint256 _tokenId) public {
        address tokenOwner = ownerOf(_tokenId);
        address payable seller = payable(address(tokenOwner));

        require(TokenState.ForSale == Bazaar[_tokenId].state, "No Sale");

        if (Bazaar[_tokenId].price >= 0) {
            uint256 fee = serviceFee(Bazaar[_tokenId].price);
            uint256 withFee = SafeMath.sub(Bazaar[_tokenId].price, fee);
            uint256 poolFee = fee.mul(80).div(100);
            uint256 ecologyFee = fee.sub(poolFee);
            uint256 burnFee = ecologyFee.div(2);
            uint256 ownerFee = ecologyFee.sub(burnFee);

            IERC20(priceToken).transferFrom(msg.sender, seller, withFee);
            IERC20(priceToken).transferFrom(msg.sender, feeReceiver, ownerFee);
            IERC20(priceToken).transferFrom(msg.sender, address(this), poolFee.add(burnFee));
            IERC20(priceToken).transferFrom(msg.sender, burnAddress, burnFee);
        }

        _transfer(ownerOf(_tokenId), msg.sender, _tokenId);
        Bazaar[_tokenId].state = TokenState.Sold;

        emit Bought(_tokenId, Bazaar[_tokenId].price);
    }
    
    function serviceFee(uint256 amount) internal pure returns (uint256) {
        uint256 fee = SafeMath.mul(amount, 5);

        return SafeMath.div(fee, 100);
    }
    
    function withdrawAll() public onlyOwner {
        // require(payable(msg.sender).send(address(this).balance));
        uint256 bal = IERC20(priceToken).balanceOf(address(this));

        IERC20(priceToken).transfer(msg.sender, bal);
    }
    
       // invocation
    event Invoke(uint256 indexed tokenId);
    mapping(uint256 => bool) public Invocations;
    
    function invokeSeal(uint256 tokenId) public {
        require(_exists(tokenId), "Cannot invoke a nonexistent token");
        require(ownerOf(tokenId) == msg.sender, "ERC721Metadata: URI query for nonexistent token");
        require(Invocations[tokenId] != true,"ALREADY INVOKED!");
        Invocations[tokenId] = true;
        emit Invoke(tokenId);
    }
}
