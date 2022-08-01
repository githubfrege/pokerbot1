using System;
using pokerlib;
using System.Linq;
using System.Collections.Generic;
using System.Collections;
using Microsoft.VisualBasic.FileIO;
using System.Diagnostics;
using System.Text.RegularExpressions;
using System.Globalization;

namespace pokerbot
{
    
    public static class Program
    {
        
        public static List<Card> AllCards = new List<Card>();
        public static List<Card> MyCards = new List<Card>();
        public static List<Card> Table = new List<Card>();
        public static double[,] PreflopMatrixSuited = new double[14,14];
        public static double[,] PreflopMatrixUnsuited = new double[14, 14];
        public static double Odds;
        public static long VillainCardSets = 0;
        
        public static List<Card> GetAvailableCards(List<Card> villainCards)
        {
            List<Card> availCards = new List<Card>();
            foreach (Card card in AllCards)
            {
                if (!MyCards.Contains(card) && !Table.Contains(card) && !villainCards.Contains(card))
                {
                    availCards.Add(card);
                }
            }
            return availCards;
            

        }
        public static Hand WinningHand(List<Hand> hands)
        {
            Hand winner = new Hand();
            foreach (Hand hand in hands)
            {
                hand.AssignScores();
            }

            foreach (Hand hand in hands)
            {
                if (hand.IsWinnerHand(hands))
                {
                    winner = hand;
                }
            }
            return winner;


        }
        public static Hand HandToPlay(List<Card> cardList, List<Card> tableCards)
        {
            List<Hand> handsToCompare = new List<Hand>();
            for (int i = 0; i < 2; i++)
            {
                for (int j = 0; j < 2; j++)
                {
                    List<Card> newCardList = new List<Card>(tableCards.GetRange(j, 4));
                    newCardList.Add(cardList[i]);
                    Hand option = new Hand { CardList = newCardList };
                    if (!handsToCompare.Contains(option))
                    {
                        handsToCompare.Add(option);
                    }
                }
               

            }
            for (int i = 0; i < 3; i++)
            {
                List<Card> newCardList = new List<Card>(tableCards.GetRange(i, 3));
                newCardList.AddRange(cardList);
                Hand option = new Hand { CardList = newCardList };
                if (!handsToCompare.Contains(option))
                {
                    handsToCompare.Add(option);
                }
            }
            return WinningHand(handsToCompare);
        }

      

        public static IEnumerable<List<Card>> CardCombos(IEnumerable<Card> cards, int count)
        {
            int i = 0;
            foreach (Card card in cards)
            {
                if (count == 1)
                {
                    yield return new List<Card>() { card };
                }
                
                else
                {
                    foreach (var result in CardCombos(cards.Skip(i + 1), count - 1))
                    {
                       
                        yield return new List<Card>(result) { card }; 
                    }
                        //yield return new Card[] { card }.Concat(result);
                }

                ++i;
            }
        }
        public static void GenerateDeck()
        {
            var ranks = Enum.GetValues(typeof(Rank));
            var suits = Enum.GetValues(typeof(Suit));
            foreach (var rank in ranks)
            {
                foreach (var suit in suits)
                {
                    Card foo = new Card { RankState = (Rank)rank, SuitState = (Suit)suit };
                    if (!AllCards.Contains(foo))
                    {
                        AllCards.Add(foo);
                    }
                    
                }
            }

        }
        public static void GetPreflopOdds()
        {
           var ranks =  Enum.GetValues(typeof(Rank));
            Array.Reverse(ranks);
            int i = Array.IndexOf(ranks, MyCards[0].RankState);
            int j = Array.IndexOf(ranks, MyCards[1].RankState);
           
            Odds = MyCards[0].SuitState.Equals(MyCards[1].SuitState) ?  PreflopMatrixSuited[i, j] : PreflopMatrixUnsuited[i,j];

        }
        public static void MakeCards(string question, List<Card> cardList)
        {


            Console.WriteLine(question);

            foreach (string cardString in Console.ReadLine().Split(" "))
            {
                try
                {
                    if (Char.IsLetter(cardString[0]))
                    {
                        cardList.Add(new Card { RankState = (Rank)Enum.Parse(typeof(Rank), cardString[0].ToString()), SuitState = (Suit)Enum.Parse(typeof(Suit), cardString[1].ToString()) });
                    }
                    else
                    {
                        int cardInt;
                        if (Char.IsDigit(cardString[1]))
                        {
                            cardInt = int.Parse(cardString.Substring(0, 2));
                        }
                        else
                        {
                            cardInt = int.Parse(cardString[0].ToString());
                        }

                        cardList.Add(new Card { RankState = (Rank)cardInt, SuitState = (Suit)Enum.Parse(typeof(Suit), cardString[1].ToString()) });
                    }
                }
                catch (IndexOutOfRangeException)
                {
                    return;
                }


            }
        }

        public static void GenerateValueMatrix(double[,] matrix, string path)
        {
            using (TextFieldParser parser = new TextFieldParser(path))
            {
                bool firstLine = true;
                parser.TextFieldType = FieldType.Delimited;
                parser.SetDelimiters(",");
                parser.HasFieldsEnclosedInQuotes = true;
                int i = 0;
                int j = 0;
                while (!parser.EndOfData)
                {

                    //Processing row
                    string[] fields = parser.ReadFields();
                    if (firstLine)
                    {
                        firstLine = false;

                        continue;
                    }
                newLine:
                    bool firstField = true;
                    foreach (string field in fields)
                    {
                        if (firstField)
                        {
                            firstField = false;

                            continue;
                        }
                        if (!String.IsNullOrEmpty(field))
                        {
                            string newField = field.Replace(',', '.').Trim(new char[] { '%', '"' });
                            double percentNumber = double.Parse(newField, CultureInfo.InvariantCulture);
                            double frac = percentNumber / 100;
                            matrix[i, j] = frac;
                        }
                        Debug.WriteLine(i);

                        i++;
                        if (i > 13)
                        {
                            i = 0;
                            j++;
                            goto newLine;
                        }
                    }

                }
            }
        }
        public static void GetOdds()
        {
            float heroWins = 0; //if player wins
            float villainWins = 0; //if bot wins
            List<Card> emptyList = new List<Card>(); //dummy list, not important, just means that the bot hasnt gotten its hole cards yet, thus cant influence result of availablecards
            List<Card> availCards = GetAvailableCards(emptyList); //all cards left in the deck (original deck with my hole cards and community cards subtracted)
            
            foreach (var villainCardSet in CardCombos(availCards, 2))
            {
                Console.WriteLine($"New villain card set {VillainCardSets}");
                VillainCardSets++;
                if (VillainCardSets == 2)
                {
                    Console.WriteLine("break now");
                }
                List<Hand> validHands = new List<Hand>();
                long okHands = 0;
                foreach (var cardSet in CardCombos(GetAvailableCards(villainCardSet), 5 - Table.Count))
                {
                    Hand hand = new Hand { CardList = new List<Card>(Table) };
                    foreach (var card in cardSet)
                    {
                        hand.CardList.Add(card);
                    }
                    validHands.Add(hand);
                    okHands++;

                }
                Console.WriteLine(okHands);
                long playedHands = 0;
                foreach (Hand hand in validHands)
                {
                    playedHands++;
                    Hand villainHand = HandToPlay(villainCardSet, hand.CardList);
                    Hand heroHand = HandToPlay(MyCards, hand.CardList);
                    switch (heroHand.CompareTo(villainHand))
                    {
                        case 1:
                            heroWins++;
                            break;
                        case -1:
                            villainWins++;
                            break;
                        case 0:
                            heroWins += 0.5f;
                            villainWins += 0.5f;
                            break;
                    }

                }
                Console.WriteLine(playedHands);
            }
            Odds = heroWins / (heroWins + villainWins);

        }

        static void Main(string[] args)
        {
          
            GenerateDeck();
            GenerateValueMatrix(PreflopMatrixSuited, @"suited.csv");
            GenerateValueMatrix(PreflopMatrixUnsuited, @"unsuited.csv");
            MakeCards("What are your cards?", MyCards);
            MakeCards("What are the the cards on the table?", Table);
            if (Table.Count == 0)
            {
                GetPreflopOdds();
            }
            else
            {
                GetOdds();
            }
            /*long combos = 0;
            List<Card> emptyList = new List<Card>();
            foreach (var cardSet in CardCombos(GetAvailableCards(emptyList), 2))
            {
                combos++;
                Console.Write(combos + " ");
            }*/
            Console.WriteLine(Odds);
           
           

           
            
               
            
           
            
           
            Console.WriteLine("Hello World!");
        }
    }
}
